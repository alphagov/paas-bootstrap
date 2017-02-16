#!/bin/sh -eu
sudo apt-get update && sudo apt-get install docker-compose -y

cd /vagrant

# Generate keys for concourse
mkdir -p keys/web keys/worker
ssh-keygen -t rsa -f ./keys/web/tsa_host_key -N ''
ssh-keygen -t rsa -f ./keys/web/session_signing_key -N ''
ssh-keygen -t rsa -f ./keys/worker/worker_key -N ''

cp ./keys/worker/worker_key.pub ./keys/web/authorized_worker_keys
cp ./keys/web/tsa_host_key.pub ./keys/worker

# shellcheck disable=SC2091
$("./environment.sh")

sudo -E docker-compose up -d
