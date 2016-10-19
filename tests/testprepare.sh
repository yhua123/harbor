#!/bin/bash

cp tests/docker-compose.test.yml Deploy/.

mkdir /etc/ui
cp Deploy/common/config/ui/private_key.pem /etc/ui/.

mkdir conf
cp Deploy/common/config/ui/app.conf conf/.
