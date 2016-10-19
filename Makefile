# Makefile for a harbor project
#	
# Targets:
#
# all, all_photon, all_ubuntu: 
#			prepare, compile, build images and install images (default: ubuntu)
# prepare: 		prepare env
# compile: 		compile ui and jobservice code
# compile_golangimage:
#			compile from golang image
# build_db_ubuntu, build_log_ubuntu, build_jobservice_ubuntu, build_ui_ubuntu:
#			build harbor ubuntu images  
# build_db_photon, build_log_photon, build_jobservice_photon, build_ui_photon:
#			build harbor photon images
# build_db, build_log, build_jobservice, build_ui:
#			build harbor images  (default: ubuntu)
# build_ubuntu: 	build harbor ubuntu images
# build_photon: 	build harbor photon images
# install, install_ubuntu, install_photon:
# 			insatll harbor images (default: ubuntu)
# stop, stop_ubuntu, stop_photon: 
# 			stop harbor images (default: ubuntu)
# cleanbinary: 		clean ui and jobservice binary
# cleanimage, cleanimage_ubuntu, cleanimage_photon: 
# 			clean harbor images (default: ubuntu)
# clean, clean_ubuntu, clean_photon:
#			clean ui/jobservice binary and harbor images (default: ubuntu)

# common
SHELL := /bin/bash
BUILDPATH=$(CURDIR)
DEPLOYPATH=$(BUILDPATH)/Deploy
DEPLOYDEVPATH=$(DEPLOYPATH)/dev
SRCPATH=./src
TOOLSPATH=$(BUILDPATH)/tools
GOBASEPATH=/go/src/github.com/vmware
CHECKENVCMD=checkenv.sh
BASEIMAGE=photon

# docker parameters
DOCKERCMD=$(shell which docker)
DOCKERBUILD=$(DOCKERCMD) build
DOCKERRMIMAGE=$(DOCKERCMD) rmi
DOCKERPULL=$(DOCKERCMD) pull
DOCKERIMASES=$(DOCKERCMD) images
DOCKERSAVE=$(DOCKERCMD) save
DOCKERCOMPOSECMD=$(shell which docker-compose)

# go parameters
GOCMD=$(shell which go)
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOINSTALL=$(GOCMD) install
GOTEST=$(GOCMD) test
GODEP=$(GOTEST) -i
GOFMT=gofmt -w
GOBUILDIMAGE=reg-bj.eng.vmware.com/harborrelease/harborgo:1.6.2
GOBUILDPATH=$(GOBASEPATH)/harbor
GOBUILDPATH_UI=$(GOBUILDPATH)/ui
GOBUILDPATH_JOBSERVICE=$(GOBUILDPATH)/jobservice
GOBUILDDEPLOYPATH=$(GOBUILDPATH)/Deploy
GOBUILDDEPLOYPATH_UI=$(GOBUILDDEPLOYPATH)/ui
GOBUILDDEPLOYPATH_JOBSERVICE=$(GOBUILDDEPLOYPATH)/jobservice

# binary 
UISOURCECODE=$(SRCPATH)/ui
UIBINARYPATH=$(DEPLOYDEVPATH)/ui
UIBINARYNAME=harbor_ui
JOBSERVICESOURCECODE=$(SRCPATH)/jobservice
JOBSERVICEBINARYPATH=$(DEPLOYDEVPATH)/jobservice
JOBSERVICEBINARYNAME=harbor_jobservice

# prepare parameters
PREPAREPATH=$(TOOLSPATH)
PREPARECMD=prepare

# configfile
CONFIGPATH=$(DEPLOYPATH)
CONFIGFILE=harbor.cfg

# makefile
MAKEFILEPATH_PHOTON=$(DEPLOYPATH)/photon
MAKEFILEPATH_UBUNTU=$(DEPLOYPATH)/ubuntu

# common dockerfile
DOCKERFILEPATH_COMMON=$(DEPLOYPATH)/common
DOCKERFILEPATH_DB=$(DOCKERFILEPATH_COMMON)/db
DOCKERFILENAME_DB=Dockerfile
DOCKERIMAGENAME_DB=vmware/harbor-db

#docker image name
DOCKERIMAGENAME_UI=vmware/harbor-ui
DOCKERIMAGENAME_JOBSERVICE=vmware/harbor-jobservice
DOCKERIMAGENAME_LOG=vmware/harbor-log
DOCKERIMAGENAME_DB=vmware/harbor-db


# docker-compose files
DOCKERCOMPOSEFILEPATH=$(DEPLOYPATH)
DOCKERCOMPOSEFILENAME=docker-compose.yml

# version prepare
VERSIONFILEPATH=$(SRCPATH)/ui/views/sections
VERSIONFILENAME=header-content.htm
GITCMD=$(shell which git)
GITTAG=$(GITCMD) describe --tags
VERSIONTAG=$(shell $(GITTAG))
SEDCMD=$(shell which sed)

#package 
TARCMD=$(shell which tar)
ZIPCMD=$(shell which gzip)
DOCKERIMGFILE=harbor
HARBORPKG=harbor

version:
	@$(SEDCMD) -i 's/version=\"{{.Version}}\"/version=\"$(VERSIONTAG)\"/' -i $(VERSIONFILEPATH)/$(VERSIONFILENAME)
	
check_environment:
	@$(TOOLSPATH)/$(CHECKENVCMD)

compile_ui:
	@echo "compiling binary for ui..."
	$(GOBUILD) -o $(UIBINARYPATH)/$(UIBINARYNAME) $(UISOURCECODE)
	@echo "Done."
	
compile_jobservice:
	@echo "compiling binary for jobservice..."
	$(GOBUILD) -o $(JOBSERVICEBINARYPATH)/$(JOBSERVICEBINARYNAME) $(JOBSERVICESOURCECODE)
	@echo "Done."
	
compile_normal: compile_ui compile_jobservice

compile_golangimage:
	@echo "pulling golang build base image"
	$(DOCKERPULL) $(GOBUILDIMAGE)
	@echo "Done."

	@echo "compiling binary for ui (golang image)..."
	@echo $(GOBASEPATH)
	@echo $(GOBUILDPATH)
	$(DOCKERCMD) run --rm -v $(BUILDPATH):$(GOBUILDPATH) -w $(GOBUILDPATH_UI) $(GOBUILDIMAGE) $(GOBUILD) -v -o $(GOBUILDDEPLOYPATH_UI)/$(UIBINARYNAME)
	@echo "Done."
	
	@echo "compiling binary for jobservice (golang image)..."
	$(DOCKERCMD) run --rm -v $(BUILDPATH):$(GOBUILDPATH) -w $(GOBUILDPATH_JOBSERVICE) $(GOBUILDIMAGE) $(GOBUILD) -v -o $(GOBUILDDEPLOYPATH_JOBSERVICE)/$(JOBSERVICEBINARYNAME)
	@echo "Done."
	
compile:check_environment compile_normal

prepare: 
	@echo "preparing..."
	$(PREPAREPATH)/$(PREPARECMD) -conf $(CONFIGPATH)/$(CONFIGFILE)
	
build_common: prepare version
	@echo "buildging db container for photon..."
	cd $(DOCKERFILEPATH_DB) && $(DOCKERBUILD) -f $(DOCKERFILENAME_DB) -t $(DOCKERIMAGENAME_DB):$(VERSIONTAG) .
	@echo "Done."
	
	@echo "pulling nginx and registry..."
	$(DOCKERPULL) registry:2.5.0
	$(DOCKERPULL) nginx:1.9
	
build_photon: build_common
	make -f $(MAKEFILEPATH_PHOTON)/Makefile build	
	
build_ubuntu: build_common
	make -f $(MAKEFILEPATH_UBUNTU)/Makefile build
	
build: build_$(BASEIMAGE)

	
modify_composefile: 
	@echo "preparing tag:$(VERSIONTAG) docker-compose file..."
	@cp $(DOCKERCOMPOSEFILEPATH)/$(DOCKERCOMPOSEFILENAME) $(DOCKERCOMPOSEFILEPATH)/docker-compose.$(VERSIONTAG).yml
	@$(SEDCMD) -i 's/image\: vmware.*/&:$(VERSIONTAG)/g' $(DOCKERCOMPOSEFILEPATH)/docker-compose.$(VERSIONTAG).yml
	
install: compile build modify_composefile
	@echo "loading harbor images..."
	$(DOCKERCOMPOSECMD) -f $(DOCKERCOMPOSEFILEPATH)/docker-compose.$(VERSIONTAG).yml up -d
	@echo "Install complete. You can visit harbor now."
	
package_online: modify_composefile
	@echo "packing online package ..."
	@cp -r Deploy $(HARBORPKG)
	@cp tools/install.sh $(HARBORPKG)/.
	@cp tools/prepare $(HARBORPKG)/.
	@$(SEDCMD) -i 's/os.path.dirname("Deploy\/")/os.path.dirname(".\/")/g' $(HARBORPKG)/prepare
	
	@cp LICENSE $(HARBORPKG)/LICENSE
	@cp NOTICE $(HARBORPKG)/NOTICE
	@$(TARCMD) -zcvf harbor-online-installer-$(VERSIONTAG).tgz \
	          --exclude=$(HARBORPKG)/common/db --exclude=$(HARBORPKG)/ubuntu \
			  --exclude=$(HARBORPKG)/photon --exclude=$(HARBORPKG)/kubernetes \
			  --exclude=$(HARBORPKG)/dev --exclude=docker-compose.yml \
			  $(HARBORPKG)
			
	@rm -rf $(HARBORPKG)
	@echo "Done."
	
package_offline: build modify_composefile
	@echo "packing offline package ..."
	@cp -r Deploy $(HARBORPKG)
	@cp tools/install.sh $(HARBORPKG)/.
	@cp tools/prepare $(HARBORPKG)/.
	@$(SEDCMD) -i 's/os.path.dirname("Deploy\/")/os.path.dirname(".\/")/g' $(HARBORPKG)/prepare
	
	@cp LICENSE $(HARBORPKG)/LICENSE
	@cp NOTICE $(HARBORPKG)/NOTICE
	@echo "saving harbor docker image"
	$(DOCKERSAVE) -o $(HARBORPKG)/$(DOCKERIMGFILE).$(VERSIONTAG).tgz \
		$(DOCKERIMAGENAME_UI):$(VERSIONTAG) \
		$(DOCKERIMAGENAME_LOG):$(VERSIONTAG) \
		$(DOCKERIMAGENAME_DB):$(VERSIONTAG) \
		$(DOCKERIMAGENAME_JOBSERVICE):$(VERSIONTAG) \
		nginx:1.9.0 registry:2.5.0

	@$(TARCMD) -zcvf harbor-offline-installer-$(VERSIONTAG).tgz \
	          --exclude=$(HARBORPKG)/common/db --exclude=$(HARBORPKG)/ubuntu \
			  --exclude=$(HARBORPKG)/photon --exclude=$(HARBORPKG)/kubernetes \
			  --exclude=$(HARBORPKG)/dev --exclude=docker-compose.yml \
			  $(HARBORPKG)
	
	@rm -rf $(HARBORPKG)
	@echo "Done."
	
start:
	@echo "loading harbor images..."
	@$(DOCKERCOMPOSECMD) -f $(DOCKERCOMPOSEFILEPATH)/docker-compose.$(VERSIONTAG).yml up -d
	@echo "Start complete. You can visit harbor now."
	
down:
	@echo "stoping harbor instance..."
	@$(DOCKERCOMPOSECMD) -f $(DOCKERCOMPOSEFILEPATH)/docker-compose.$(VERSIONTAG).yml down
	@echo "Done."

cleanbinary:
	@echo "cleaning binary..."
	@if [ -f $(UIBINARYPATH)/$(UIBINARYNAME) ] ; then rm $(UIBINARYPATH)/$(UIBINARYNAME) ; fi
	@if [ -f $(JOBSERVICEBINARYPATH)/$(JOBSERVICEBINARYNAME) ] ; then rm $(JOBSERVICEBINARYPATH)/$(JOBSERVICEBINARYNAME) ; fi

cleanimage:
	@echo "cleaning image for photon..."
	- $(DOCKERRMIMAGE) -f $(DOCKERIMAGENAME_UI):$(VERSIONTAG)
	- $(DOCKERRMIMAGE) -f $(DOCKERIMAGENAME_DB):$(VERSIONTAG)
	- $(DOCKERRMIMAGE) -f $(DOCKERIMAGENAME_JOBSERVICE):$(VERSIONTAG)
	- $(DOCKERRMIMAGE) -f $(DOCKERIMAGENAME_LOG):$(VERSIONTAG)
	- $(DOCKERRMIMAGE) -f registry:2.5.0
	- $(DOCKERRMIMAGE) -f nginx:1.9

cleandockercomposefile:
	@echo "cleaning $(DOCKERCOMPOSEFILEPATH)/docker-compose.$(VERSIONTAG).yml"
	@if [ -f $(DOCKERCOMPOSEFILEPATH)/docker-compose.$(VERSIONTAG).yml ] ; then rm $(DOCKERCOMPOSEFILEPATH)/docker-compose.$(VERSIONTAG).yml ; fi

cleanversiontag:
	@echo "cleaning version TAG"
	@$(SEDCMD) -i 's/version=\"$(VERSIONTAG)\"/version=\"{{.Version}}\"/' -i $(VERSIONFILEPATH)/$(VERSIONFILENAME)
	
cleanpackage:
	@echo "cleaning harbor install package"
	@if [ -d $(BUILDPATH)/harbor ] ; then rm -rf $(BUILDPATH)/harbor ; fi
	@if [ -f $(BUILDPATH)/harbor-online-installer-$(VERSIONTAG).tgz ] ; \
	then rm $(BUILDPATH)/harbor-online-installer-$(VERSIONTAG).tgz ; fi
	@if [ -f $(BUILDPATH)/harbor-offline-installer-$(VERSIONTAG).tgz ] ; \
	then rm $(BUILDPATH)/harbor-offline-installer-$(VERSIONTAG).tgz ; fi	
	
.PHONY: clean
clean: cleanbinary cleanimage cleandockercomposefile cleanversiontag cleanpackage

all: prepare install

