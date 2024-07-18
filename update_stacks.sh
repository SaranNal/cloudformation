#!/bin/bash

# Function to create or update a change set for a given stack
create_change_set() {
  local stack_name=$1
  local stack_env=$2
  local template_url=$3
  local parameters=$4

  local full_stack_name="${stack_name}-stack-${stack_env}"
  local change_set_name="${stack_name}-changeset"

  if aws cloudformation describe-stacks --stack-name "${full_stack_name}" >/dev/null 2>&1; then
    echo "Updating ${full_stack_name}..."
    
    aws cloudformation create-change-set --stack-name "${full_stack_name}" \
      --template-url "${template_url}" \
      --change-set-name "${change_set_name}" \
      --capabilities CAPABILITY_NAMED_IAM \
      --include-nested-stacks \
      --parameters ${parameters}

    aws cloudformation wait change-set-create-complete --stack-name "${full_stack_name}" --change-set-name "${change_set_name}"
    aws cloudformation describe-change-set --stack-name "${full_stack_name}" --change-set-name "${change_set_name}"
  else
    echo "Stack ${full_stack_name} does not exist."
  fi
}

# Define stack parameters
STACK_ENV=${StackENV}
COMMON_PARAMETERS="ParameterKey=Environment,ParameterValue=${Environment} ParameterKey=ProjectName,ParameterValue=${ProjectName} ParameterKey=CodeStarConnectionID,ParameterValue=${CodeStarConnectionID} ParameterKey=StackBucketName,ParameterValue=${CLONE_TEMPLATE_BUCKET}"

# Define stacks and their specific parameters
declare -A stacks
stacks[helper]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/helper-stack/RootStack.yaml ${COMMON_PARAMETERS} ParameterKey=S3LogBucket,ParameterValue=${S3LogBucket}"
stacks[network]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/network-stack/RootStack.yaml ${COMMON_PARAMETERS} ParameterKey=Environment,ParameterValue=${Environment} ParameterKey=ProjectName,ParameterValue=${ProjectName}"
stacks[infra]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/infra-stack/RootStack.yaml ${COMMON_PARAMETERS} ParameterKey=SSLCertificateID,ParameterValue=${SSLCertificateID}"

# Loop through each stack and create/update the change set
for stack_name in "${!stacks[@]}"; do
  IFS=' ' read -r -a stack_params <<< "${stacks[$stack_name]}"
  template_url=${stack_params[0]}
  parameters=${stacks[$stack_name]#"$template_url "}
  create_change_set "${stack_name}" "${STACK_ENV}" "${template_url}" "${parameters}"
done
