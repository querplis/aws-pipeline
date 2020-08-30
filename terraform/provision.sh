#!/bin/bash
apt-get update && \
apt-get install -y curl jq ruby

REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r ".region")

cd /tmp/
wget https://aws-codedeploy-${REGION}.s3.amazonaws.com/latest/install
chmod +x ./install

if ./install auto; then
  echo "Instalation completed"
  rm -f /tmp/install
  exit 0
else
  echo "Instalation script failed, please investigate"
  rm -f /tmp/install
  exit 1
fi
