#!/bin/bash
# network_stack_parameters.sh

STACK_ENV="dev"
Environment="dev"
ProjectName="saran"
CLONE_TEMPLATE_BUCKET="my-clone-template-bucket"

NETWORK_STACK_PARAMETERS="ParameterKey=Environment,ParameterValue=${Environment} ParameterKey=STACK_ENV,ParameterValue=${STACK_ENV} ParameterKey=ProjectName,ParameterValue=${ProjectName} ParameterKey=StackBucketName,ParameterValue=${CLONE_TEMPLATE_BUCKET}"
