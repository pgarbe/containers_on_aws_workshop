#!/bin/bash -e
stackname=todo-docker-swarm

aws s3api create-bucket --bucket $stackname
aws s3 cp . s3://$stackname/ --recursive --include "*.yaml"

if [[ $((aws cloudformation describe-stacks --stack-name $stackname) 2> /dev/null) ]]; then
  aws cloudformation update-stack \
      --template-body file://./stack.yaml \
      --stack-name $stackname \
      --capabilities CAPABILITY_IAM \
      --parameters ParameterKey=Version,ParameterValue=$(date +%s) $@
else
  aws cloudformation create-stack \
      --template-body file://./stack.yaml \
      --stack-name $stackname \
      --capabilities CAPABILITY_IAM \
      --parameters ParameterKey=Version,ParameterValue=$(date +%s) $@
fi
