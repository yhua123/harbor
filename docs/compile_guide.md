## Introduction

This guide provides instructions for developers to build and run Harbor from source code. 

## Step 1: Prepare for a build environment for Harbor

Harbor is deployed as several Docker containers and most of the code is written in Go language. The build host requires Python, Docker, Docker Compose and golang development environment. Please install the below prerequisites:


Software              | Required Version
----------------------|--------------------------
docker                | 1.10.0 +
docker-compose        | 1.7.1 +
python                | 2.7 +
git                   | 1.9.1 +
make                  | 3.81 +
golang*               | 1.6.0 +
 *optional


## Step 2: Getting the source code

   ```sh
      $ git clone https://github.com/vmware/harbor
   ```

## Step 3: Resolving dependencies of Go language
You can compile the source code by using a Golang dev image. In this case, you can skip this step. 

If you are building Harbor using your own Go compiling environment. You need to install LDAP packages manually. 

For PhotonOS:

   ```sh
      $ tdnf install -y sed apr-util-ldap
   ```

For Ubuntu:

   ```sh
      $ apt-get update && apt-get install -y libldap2-dev
   ```

For other platforms, please consult the relevant documentation of installing LDAP package.

## Step 4: Building and installing Harbor

### Configuration

Edit the file **make/harbor.cfg** and make necessary configuration changes such as hostname, admin password and mail server. Refer to **[Installation and Configuration Guide](installation_guide.md#configuring-harbor)** for more info. 

   ```sh
      $ cd harbor
      $ vi make/harbor.cfg
   ```
   
### Compiling and Running

You can compile the code by one of the three approaches:

#### I. Create a Golang dev image, then build Harbor

* Build Golang dev image:

   ```sh
      $ make compile_buildgolangimage -e GOBUILDIMAGE=harborgo:1.6.2
   ```

*  Build, install and bring up Harbor:

   ```sh
      $ make install -e GOBUILDIMAGE=harborgo:1.6.2 COMPILETAG=compile_golangimage
   ```

#### II. Compile code with your own Golang environment, then build Harbor

* Move source code to $GOPATH

   ```sh
      $ mkdir $GOPATH/src/github.com/vmware/
      $ cd ..
      $ mv harbor $GOPATH/src/github.com/vmware/.
   ```

*  Build, install and run Harbor

   ```sh
      $ cd $GOPATH/src/github.com/vmware/harbor
      $ make install
   ```
   
#### III. Manual build process (compatible with previous versions)

   ```sh
      $ cd make
   
      $ ./prepare
      Generated configuration file: ./config/ui/env
      Generated configuration file: ./config/ui/app.conf
      Generated configuration file: ./config/registry/config.yml
      Generated configuration file: ./config/db/env
      ...
   
      $ cd dev
      
      $ docker-compose up -d
   ```

### Verify your installation

If everyting worked properly, you can get the below message:

   ```sh
      ...
      ----Harbor has been installed and started successfully.----

      Now you should be able to visit the admin portal at http://$YOURIP. 
      For more details, please visit https://github.com/vmware/harbor .
   ```

Refer to [Installation and Configuration Guide](installation_guide.md#managing-harbors-lifecycle) for more information about managing your Harbor instance.   

## Appendix
* Using the Makefile

The `Makefile` contains these configurable parameters:

Variable           | Description
-------------------|-------------
BASEIMAGE          | Container base image, default: photon
DEVFLAG            | Build model flag, default: dev
COMPILETAG         | Compile model flag, default: compile_normal (local golang build)
REGISTRYSERVER     | Remote registry server IP address
REGISTRYUSER       | Remote registry server user name
REGISTRYPASSWORD   | Remote registry server user password
REGISTRYPROJECTNAME| Project name on remote registry server

* Predefined targets:

Target              | Description
--------------------|-------------
all                 | prepare env, compile binaries, build images and install images 
prepare             | prepare env
compile             | compile ui and jobservice code
compile_golangimage | compile local golang image
compile_ui          | compile ui binary
compile_jobservice  | compile jobservice binary
build               | build Harbor docker images (default: using build_photon)
build_photon        | build Harbor docker images from Photon OS base image
build_ubuntu        | build Harbor docker images from Ubuntu base image
install             | compile binaries, build images, prepare specific version of compose file and startup Harbor instance
start               | startup Harbor instance 
down                | shutdown Harbor instance
package_online      | prepare online install package
package_offline     | prepare offline install package
pushimage           | push Harbor images to specific registry server
clean all           | remove binary, Harbor images, specific version docker-compose file, specific version tag and online/offline install package
cleanbinary         | remove ui and jobservice binary
cleanimage          | remove Harbor images 
cleandockercomposefile  | remove specific version docker-compose 
cleanversiontag     | remove specific version tag
cleanpackage        | remove online/offline install package

#### EXAMPLE:

#### Build a golang dev image (for building Harbor):

   ```sh
      $ make compile_golangimage -e GOBUILDIMAGE= [$YOURIMAGE]

   ```

#### Build Harbor images based on Ubuntu

   ```sh
      $ make build -e BASEIMAGE=ubuntu

   ```

#### Push Harbor images to specific registry server

   ```sh
      $ make pushimage -e DEVFLAG=false REGISTRYSERVER=[$SERVERADDRESS] REGISTRYUSER=[$USERNAME] REGISTRYPASSWORD=[$PASSWORD] REGISTRYPROJECTNAME=[$PROJECTNAME]

   ```

   **Note**: need add "/" on end of REGISTRYSERVER. If REGISTRYSERVER is not set, images will be pushed directly to Docker Hub.


   ```sh
      $ make pushimage -e DEVFLAG=false REGISTRYUSER=[$USERNAME] REGISTRYPASSWORD=[$PASSWORD] REGISTRYPROJECTNAME=[$PROJECTNAME]

   ```

#### Clean up binaries and images of a specific version

   ```sh
      $ make clean -e VERSIONTAG=[TAG]

   ```
   **Note**: If new code had been added to Github, the git commit TAG will change. Better use this command to clean up images and files of previous TAG. 

#### By default, the make process create a development build. To create a release build of Harbor, set the below flag to false.

   ```sh
      $ make XXXX -e DEVFLAG=false

   ```

