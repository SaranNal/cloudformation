#!/bin/bash
# network_stack_parameters.sh

STACK_ENV="dev"
Environment="dev"
ProjectName="saran"
CLONE_TEMPLATE_BUCKET="test-cloudformation-template-clone-stack"

NETWORK_STACK_PARAMETERS="ParameterKey=Environment,ParameterValue=${Environment} ParameterKey=ProjectName,ParameterValue=${ProjectName} ParameterKey=StackBucketName,ParameterValue=${CLONE_TEMPLATE_BUCKET}"
