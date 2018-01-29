# User Guide of Harbor Virtual Appliance

## Overview

This guide walks you through the fundamentals of using Harbor virtual appliance. You'll learn how to use Harbor to:  

* Manage your projects.
* Manage members of a project.
* Replicate projects to a remote registry.
* Search projects and repositories.
* Manage Harbor system if you are the system administrator:
 + Manage users.
 + Manage destinations.
 + Manage replication policies.
* Pull and push images using Docker client.
* Delete repositories and images.


## Role Based Access Control

![rbac](img/rbac.png)

In Harbor, images are grouped under projects. To access an image, a user should be added as a member into the project of the image. A member can have one of the three roles:  

* **Guest**: Guest has read-only privilege for a specified project.
* **Developer**: Developer has read and write privileges for a project.
* **ProjectAdmin**: When creating a new project, you will be assigned the "ProjectAdmin" role to the project. Besides read-write privileges, the "ProjectAdmin" also has some management privileges, such as adding and removing members.

Besides the above three roles, there are two system-wide roles:  

* **SysAdmin**: "SysAdmin" has the most privileges. In addition to the privileges mentioned above, "SysAdmin" can also list all projects, set an ordinary user as administrator and delete users. The public project "library" is also owned by the administrator.  
* **Anonymous**: When a user is not logged in, the user is considered as an "anonymous" user. An anonymous user has no access to private projects and has read-only access to public projects.  

## User account
Harbor supports two authentication modes:  

* **Database(db_auth)**  

	Users are stored in the local database.  
	
	A user can register himself/herself in Harbor in this mode. To disable user self-registration, refer to the **[installation guide](installation_guide_ova.md)**. When self-registration is disabled, the system administrator can add users in Harbor.  
	
	When registering or adding a new user, the username and email must be unique in the Harbor system. The password must contain at least 8 characters, less than 20 characters with 1 lowercase letter, 1 uppercase letter and 1 numeric character.  
	
	When you forgot your password, you can follow the below steps to reset the password:  

	1. Click the link "Forgot Password" in the sign in page.  
	2. Input the email address entered when you signed up, an email will be sent out to you for password reset.  
	3. After receiving the email, click on the link in the email which directs you to a password reset web page.  
	4. Input your new password and click "Save".  
	
* **LDAP/Active Directory (ldap_auth)**  

	Under this authentication mode, users whose credentials are stored in an external LDAP or AD server can log in to Harbor directly.  
	
	When an LDAP/AD user logs in by *username* and *password*, Harbor binds to the LDAP/AD server with the **"LDAP Search DN"** and **"LDAP Search Password"** described in [installation guide](installation_guide_ova.md). If it successes, Harbor looks up the user under the LDAP entry **"LDAP Base DN"** including substree. The attribute (such as uid, cn) specified by **"LDAP UID"** is used to match a user with the *username*. If a match is found, the user's *password* is verified by a bind request to the LDAP/AD server.  
	
	Self-registration, changing password and resetting password are not supported anymore under LDAP/AD authentication mode because the users are managed by LDAP or AD.  

## Managing projects
A project in Harbor contains all repositories of an application. No images can be pushed to Harbor before the project is created. RBAC is applied to a project. There are two types of projects in Harbor:  

* **Public**: All users have the read privilege to a public project, it's convenient for you to share some repositories with others in this way.
* **Private**: A private project can only be accessed by users with proper privileges.  

You can create a project after you signed in. Enabling the "Public" checkbox makes the project public.  

![create project](img/new_create_project.png)  

After the project is created, you can browse repositories, users and logs using the navigation tab.  

![browse project](img/new_browse_project.png)  

All logs can be listed by clicking "Logs". You can apply a filter by username, or operations and dates under "Advanced Search".  

![browse project](img/new_project_log.png)  

## Managing members of a project 
### Adding members
You can add members with different roles to an existing project.  

![browse project](img/new_add_member.png)

### Updating and removing members
You can update or remove a member by clicking the icon on the right.  

![browse project](img/new_remove_update_member.png)

## Replicating images
Images can be replicated between Harbor instances. It can be used to transfer images from one data center to another, or from an on-prem registry to an instance in the cloud.  

A replication policy needs to be set up on the source instance to govern the replication process. 
One key fact about the replication is that only images are replicated between Harbor instances. 
Users, roles and other information are not replicated. As such, always keep in mind that the user, roles and policy information is individually managed by each Harbor instance.

The replication is project-based. When a system administrator sets a policy to a project, all repositories under the project will be replicated to the remote registry. A replication job will be scheduled for each repository. 
If the project does not exist on the remote registry, a new project is created automatically.
If the project already exists and the replication user configured in the policy has no write privilege to it, 
the process will fail. 

When the policy is first enabled, all images of the project are replicated to the remote registry. Images subsequently pushed to the project on the source registry
will be incrementally replicated to the remote instance. When an image is deleted from the source registry, the policy ensures that the remote registry deletes the same image as well.
Please note, the user and member information will not be replicated.  

Depending on the size of the images and the network condition, the replication requires some time to complete. On the remote registry, an image is not available until
all its layers have been synchronized from the source. If a replication job fails due to some network issue, the job will be scheduled for a retry after a few minutes.
Always checks the log to see if there is any error of the replication. When a policy is disabled (stopped), Harbor tries to stop all existing jobs. It may take a while
before all jobs finish. A policy can be restarted by disabling and then enabling it again.  

To enable image replication, a policy must first be created. Click "Add New Policy" on the "Replication" tab, fill the necessary fields, if there is no destination in the list, you need to create one, and then click "OK", a policy for this project will be created. If  "Enable" is chosen, the project will be replicated to the remote immediately.  

**Note:** Set **"Verify Remote Cert"** to off according to the [installation guide](installation_guide_ova.md) if the destination uses a self-signed or untrusted certificate. 

![browse project](img/new_create_policy.png)

You can enable, disable or delete a policy in the policy list view. Only policies which are disabled can be edited. Only policies which are disabled and have no running jobs can be deleted. If a policy is disabled, the running jobs under it will be stopped.  

Click on a policy, jobs belonging to this policy will be listed. A job represents the progress of replicating a repository to the remote instance.  

![browse project](img/new_policy_list.png)

## Searching projects and repositories
Entering a keyword in the search field at the top lists all matching projects and repositories. The search result includes both public and private repositories you have access privilege to.  

![browse project](img/new_search.png)

## Administrator options
### Managing users
Administrator can add "administrator" role to an ordinary user by toggling the switch under "Administrator". To delete a user, click on the recycle bin icon.  

![browse project](img/new_set_admin_remove_user.png)

### Managing destination
You can list, add, edit and delete destinations in the "Destination" tab. Only destinations which are not referenced by any policies can be edited.  

![browse project](img/new_manage_destination.png)

### Managing replication
You can list, edit, enable and disable policies in the "Replication" tab. Make sure the policy is disabled before you edit it.  

![browse project](img/new_manage_replication.png)

## Pulling and pushing images using Docker client

**NOTE: Harbor only supports Registry V2 API. You need to use Docker client 1.6.0 or higher.**  

Harbor uses HTTPS for secure communication by default. A self-signed certificate is generated at first boot based on its FQDN (Fully Qualified Domain Name) or IP address. If you use Docker client to interact with it, there are two options you can choose:  

1. Trust the certificate of Harbor's CA  
Refer to the "Getting Certificate of Harbor's CA" part of [installation guide](installation_guide_ova.md).  
2. Set "--insecure-registry" option  
Add "--insecure-registry" option to /etc/default/docker (ubuntu) or /etc/sysconfig/docker (centos) and restart Docker service.  
	
If Harbor is configured as using HTTP, just set the "--insecure-registry" option.  

If the certificate used by Harbor is signed by a trusted authority, Docker should work without any additional configuration.  

### Pulling images
If the project that the image belongs to is private, you should sign in first:  

```sh
$ docker login 10.117.169.182  
```
  
You can now pull the image:  

```sh
$ docker pull 10.117.169.182/library/ubuntu:14.04  
```

**Note: Replace "10.117.169.182" with the IP address or domain name of your Harbor node.**

### Pushing images
Before pushing an image, you must create a corresponding project on Harbor web UI. 

First, log in from Docker client:  

```sh
$ docker login 10.117.169.182  
```
  
Tag the image:  

```sh
$ docker tag ubuntu:14.04 10.117.169.182/demo/ubuntu:14.04  
``` 

Push the image:

```sh
$ docker push 10.117.169.182/demo/ubuntu:14.04  
```  

**Note: Replace "10.117.169.182" with the IP address or domain name of your Harbor node.**

## Deleting repositories

Repository deletion runs in two steps.  

First, delete a repository in Harbor's UI. This is soft deletion. You can delete the entire repository or just a tag of it. After the soft deletion, 
the repository is no longer managed in Harbor, however, the files of the repository still remain in Harbor's storage.  

![browse project](img/new_delete_repository.png)

**CAUTION: If both tag A and tag B refer to the same image, after deleting tag A, B will also get deleted.**  

Next, set **"Garbage Collection"** to true according to the [installation guide](installation_guide_ova.md)(skip this step if this flag has already been set) and reboot the VM, Harbor will perform garbage collection when it boots up.  

For more information about garbage collection, please see Docker's document on [GC](https://github.com/docker/docker.github.io/blob/master/registry/garbage-collection.md).  
