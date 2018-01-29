/*
   Copyright (c) 2016 VMware, Inc. All Rights Reserved.
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

package token

import (
	"crypto"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/vmware/harbor/src/common/dao"
	"github.com/vmware/harbor/src/common/utils/log"
	"github.com/vmware/harbor/src/ui/config"

	"github.com/docker/distribution/registry/auth/token"
	"github.com/docker/libtrust"
)

const (
	issuer     = "registry-token-issuer"
	privateKey = "/etc/ui/private_key.pem"
)

var expiration int //minutes

func init() {
	expiration = config.TokenExpiration()
	log.Infof("token expiration: %d minutes", expiration)
}

// GetResourceActions ...
func GetResourceActions(scopes []string) []*token.ResourceActions {
	log.Debugf("scopes: %+v", scopes)
	var res []*token.ResourceActions
	for _, s := range scopes {
		if s == "" {
			continue
		}
		items := strings.Split(s, ":")
		length := len(items)

		typee := items[0]

		name := ""
		if length > 1 {
			name = items[1]
		}

		actions := []string{}
		if length > 2 {
			actions = strings.Split(items[2], ",")
		}

		res = append(res, &token.ResourceActions{
			Type:    typee,
			Name:    name,
			Actions: actions,
		})
	}
	return res
}

// FilterAccess modify the action list in access based on permission
func FilterAccess(username string, a *token.ResourceActions) {

	if a.Type == "registry" && a.Name == "catalog" {
		log.Infof("current access, type: %s, name:%s, actions:%v \n", a.Type, a.Name, a.Actions)
		return
	}

	//clear action list to assign to new acess element after perm check.
	a.Actions = []string{}
	if a.Type == "repository" {
		repoSplit := strings.Split(a.Name, "/")
		repoLength := len(repoSplit)
		if repoLength > 1 { //Only check the permission when the requested image has a namespace, i.e. project
			var projectName string
			registryURL := config.ExtRegistryURL()
			if repoSplit[0] == registryURL {
				projectName = repoSplit[1]
				log.Infof("Detected Registry URL in Project Name. Assuming this is a notary request and setting Project Name as %s\n", projectName)
			} else {
				projectName = repoSplit[0]
			}
			var permission string
			if len(username) > 0 {
				isAdmin, err := dao.IsAdminRole(username)
				if err != nil {
					log.Errorf("Error occurred in IsAdminRole: %v", err)
				}
				if isAdmin {
					exist, err := dao.ProjectExists(projectName)
					if err != nil {
						log.Errorf("Error occurred in CheckExistProject: %v", err)
						return
					}
					if exist {
						permission = "RWM"
					} else {
						permission = ""
						log.Infof("project %s does not exist, set empty permission for admin\n", projectName)
					}
				} else {
					permission, err = dao.GetPermission(username, projectName)
					if err != nil {
						log.Errorf("Error occurred in GetPermission: %v", err)
						return
					}
				}
			}
			if strings.Contains(permission, "W") {
				a.Actions = append(a.Actions, "push")
			}
			if strings.Contains(permission, "M") {
				a.Actions = append(a.Actions, "*")
			}
			if strings.Contains(permission, "R") || dao.IsProjectPublic(projectName) {
				a.Actions = append(a.Actions, "pull")
			}
		}
	}
	log.Infof("current access, type: %s, name:%s, actions:%v \n", a.Type, a.Name, a.Actions)
}

// GenTokenForUI is for the UI process to call, so it won't establish a https connection from UI to proxy.
func GenTokenForUI(username string, service string, scopes []string) (token string, expiresIn int, issuedAt *time.Time, err error) {
	access := GetResourceActions(scopes)
	for _, a := range access {
		FilterAccess(username, a)
	}
	return MakeToken(username, service, access)
}

// MakeToken makes a valid jwt token based on parms.
func MakeToken(username, service string, access []*token.ResourceActions) (token string, expiresIn int, issuedAt *time.Time, err error) {
	pk, err := libtrust.LoadKeyFile(privateKey)
	if err != nil {
		return "", 0, nil, err
	}
	tk, expiresIn, issuedAt, err := makeTokenCore(issuer, username, service, expiration, access, pk)
	if err != nil {
		return "", 0, nil, err
	}
	rs := fmt.Sprintf("%s.%s", tk.Raw, base64UrlEncode(tk.Signature))
	return rs, expiresIn, issuedAt, nil
}

//make token core
func makeTokenCore(issuer, subject, audience string, expiration int,
	access []*token.ResourceActions, signingKey libtrust.PrivateKey) (t *token.Token, expiresIn int, issuedAt *time.Time, err error) {

	joseHeader := &token.Header{
		Type:       "JWT",
		SigningAlg: "RS256",
		KeyID:      signingKey.KeyID(),
	}

	jwtID, err := randString(16)
	if err != nil {
		return nil, 0, nil, fmt.Errorf("Error to generate jwt id: %s", err)
	}

	now := time.Now().UTC()
	issuedAt = &now
	expiresIn = expiration * 60

	claimSet := &token.ClaimSet{
		Issuer:     issuer,
		Subject:    subject,
		Audience:   audience,
		Expiration: now.Add(time.Duration(expiration) * time.Minute).Unix(),
		NotBefore:  now.Unix(),
		IssuedAt:   now.Unix(),
		JWTID:      jwtID,
		Access:     access,
	}

	var joseHeaderBytes, claimSetBytes []byte

	if joseHeaderBytes, err = json.Marshal(joseHeader); err != nil {
		return nil, 0, nil, fmt.Errorf("unable to marshal jose header: %s", err)
	}
	if claimSetBytes, err = json.Marshal(claimSet); err != nil {
		return nil, 0, nil, fmt.Errorf("unable to marshal claim set: %s", err)
	}

	encodedJoseHeader := base64UrlEncode(joseHeaderBytes)
	encodedClaimSet := base64UrlEncode(claimSetBytes)
	payload := fmt.Sprintf("%s.%s", encodedJoseHeader, encodedClaimSet)

	var signatureBytes []byte
	if signatureBytes, _, err = signingKey.Sign(strings.NewReader(payload), crypto.SHA256); err != nil {
		return nil, 0, nil, fmt.Errorf("unable to sign jwt payload: %s", err)
	}

	signature := base64UrlEncode(signatureBytes)
	tokenString := fmt.Sprintf("%s.%s", payload, signature)
	t, err = token.NewToken(tokenString)
	return
}

func randString(length int) (string, error) {
	const alphanum = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	rb := make([]byte, length)
	_, err := rand.Read(rb)
	if err != nil {
		return "", err
	}
	for i, b := range rb {
		rb[i] = alphanum[int(b)%len(alphanum)]
	}
	return string(rb), nil
}

func base64UrlEncode(b []byte) string {
	return strings.TrimRight(base64.URLEncoding.EncodeToString(b), "=")
}
