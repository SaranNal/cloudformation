#!/bin/bash
# network_stack_parameters.sh

STACK_ENV="dev"
Environment="dev"
ProjectName="saran"
CodeStarConnectionID="93b8e92b-c501-4fb7-a30d-487c138b6d46"
CLONE_TEMPLATE_BUCKET="my-clone-template-bucket"

NETWORK_STACK_PARAMETERS="ParameterKey=Environment,ParameterValue=${Environment} ParameterKey=ProjectName,ParameterValue=${ProjectName} ParameterKey=StackBucketName,ParameterValue=${CLONE_TEMPLATE_BUCKET}"
