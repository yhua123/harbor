#/bin/bash

#docker version: 1.11.2 
#docker-compose version: 1.7.1 
#Harbor version: 0.4.0 

set -e

usage=$'Checking environment for harbor build and install. Include golang, docker and docker-compose.'

while [ $# -gt 0 ]; do
        case $1 in
            --help)
            echo "$usage"
            exit 0;;
            *)
            echo "$usage"
            exit 1;;
        esac
        shift || true
done

function check_golang {
	if ! go version &> /dev/null
	then
		echo "No golang package in your enviroment. You should use golang docker image build binary."
		return
	fi
	
	# docker has been installed and check its version
	if [[ $(go version) =~ (([0-9]+).([0-9]+).([0-9]+)) ]]
	then
		golang_version=${BASH_REMATCH[1]}
		golang_version_part1=${BASH_REMATCH[2]}
		golang_version_part2=${BASH_REMATCH[3]}
		
		# the version of golang does not meet the requirement
		if [ "$golang_version_part1" -lt 1 ] || ([ "$golang_version_part1" -eq 1 ] && [ "$golang_version_part2" -lt 6 ])
		then
			echo "Need to upgrade golang package to 1.6.0+."
			exit 1
		else
			echo "golang version: $golang_version"
		fi
	else
		echo "Failed to parse golang version."
		exit 1
	fi
}

function check_docker {
	if ! docker --version &> /dev/null
	then
		echo "Need to install docker(1.10.0+) first and run this script again."
		exit 1
	fi
	
	# docker has been installed and check its version
	if [[ $(docker --version) =~ (([0-9]+).([0-9]+).([0-9]+)) ]]
	then
		docker_version=${BASH_REMATCH[1]}
		docker_version_part1=${BASH_REMATCH[2]}
		docker_version_part2=${BASH_REMATCH[3]}
		
		# the version of docker does not meet the requirement
		if [ "$docker_version_part1" -lt 1 ] || ([ "$docker_version_part1" -eq 1 ] && [ "$docker_version_part2" -lt 10 ])
		then
			echo "Need to upgrade docker package to 1.10.0+."
			exit 1
		else
			echo "docker version: $docker_version"
		fi
	else
		echo "Failed to parse docker version."
		exit 1
	fi
}

function check_dockercompose {
	if ! docker-compose --version &> /dev/null
	then
		echo "Need to install docker-compose(1.7.1+) by yourself first and run this script again."
		docker_compose_install
		exit $?
	fi
	
	# docker-compose has been installed, check its version
	if [[ $(docker-compose --version) =~ (([0-9]+).([0-9]+).([0-9]+)) ]]
	then
		docker_compose_version=${BASH_REMATCH[1]}
		docker_compose_version_part1=${BASH_REMATCH[2]}
		docker_compose_version_part2=${BASH_REMATCH[3]}
		
		# the version of docker-compose does not meet the requirement
		if [ "$docker_compose_version_part1" -lt 1 ] || ([ "$docker_compose_version_part1" -eq 1 ] && [ "$docker_compose_version_part2" -lt 6 ])
		then
			echo "Need to upgrade docker-compose package to 1.7.1+."
		else
			echo "docker-compose version: $docker_compose_version"
		fi
	else
		echo "Failed to parse docker-compose version."
		exit 1
	fi
}

check_golang
check_docker
check_dockercompose
