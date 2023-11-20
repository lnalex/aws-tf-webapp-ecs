#!/bin/bash -xe
if [ -z "$1" ]; then
    echo "no environment specified"
else
    stage=$1
    terraform workspace select $stage
    terraform apply -var-file vars/$stage.tfvars
fi