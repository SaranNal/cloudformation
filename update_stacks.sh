#!/bin/bash

# Function to create or update a change set for a given stack
create_change_set() {
  stack_name=$1
  stack_env=$2
  template_url=$3
  parameters=$4

  full_stack_name="${stack_name}-stack-${stack_env}"
  change_set_name="${stack_name}-changeset"

  if aws cloudformation describe-stacks --stack-name "${full_stack_name}" >/dev/null 2>&1; then
    echo "Updating ${full_stack_name}..."
    
    aws cloudformation create-change-set --stack-name "${full_stack_name}" \
      --template-url "${template_url}" \
      --change-set-name "${change_set_name}" \
      --capabilities CAPABILITY_NAMED_IAM \
      --include-nested-stacks \
      --parameters ${parameters}

    aws cloudformation wait change-set-create-complete --stack-name "${full_stack_name}" --change-set-name "${change_set_name}"
    
    change_set_status=$(aws cloudformation describe-change-set --stack-name "${full_stack_name}" --change-set-name "${change_set_name}" --query 'Status' --output text)
    echo "Change set status: ${change_set_status}"
    
    if [ "${change_set_status}" == "CREATE_COMPLETE" ]; then
      notify_teams "${full_stack_name}" "${change_set_status}"
    fi
    
  else
    echo "Stack ${full_stack_name} does not exist."
  fi
}

# Function to send notifications to Microsoft Teams
notify_teams() {
  STACK_NAME=$1
  STATUS=$2
  STACK_URL="https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks?filteringText=&filteringStatus=active&viewNested=false"
  
  if [ "${STATUS}" == "CREATE_COMPLETE" ]; then
    MESSAGE="Some new changes have occurred in **${STACK_NAME}**. Please review and approve to execute."
  elif [ "${STATUS}" == "FAILED" ]; then
    MESSAGE="No changes detected in **${STACK_NAME}**."
  else
    MESSAGE="Unknown status ${STATUS} for stack **${STACK_NAME}**."
  fi

  WEBHOOK_URL="https://knackforge.webhook.office.com/webhookb2/93eea688-6368-4c47-8d54-92a7ba364b30@196eed21-c67a-4aae-a70b-9f97644d5d14/IncomingWebhook/a5fab871a77e4c3ab1f770a1ba50c18f/73c1d036-08b9-4dd3-8346-afa964097b0a"
  PAYLOAD="{\"text\": \"${MESSAGE}<br>Status: **${STATUS}**.<br>CloudFormation Stack URL: ${STACK_URL}\"}"
  
  curl -H "Content-Type: application/json" -d "${PAYLOAD}" "${WEBHOOK_URL}"
}

# Define stack parameters
STACK_ENV=${StackENV}
COMMON_PARAMETERS="ParameterKey=Environment,ParameterValue=${Environment} ParameterKey=ProjectName,ParameterValue=${ProjectName} ParameterKey=CodeStarConnectionID,ParameterValue=${CodeStarConnectionID} ParameterKey=StackBucketName,ParameterValue=${CLONE_TEMPLATE_BUCKET}"

# Define stacks and their specific parameters
declare -A stacks
stacks[helper-stack]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/helper-stack/RootStack.yaml ${COMMON_PARAMETERS} ParameterKey=S3LogBucket,ParameterValue=${S3LogBucket}"
stacks[network-stack]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/network-stack/RootStack.yaml ParameterKey=Environment,ParameterValue=${Environment} ParameterKey=ProjectName,ParameterValue=${ProjectName} ParameterKey=StackBucketName,ParameterValue=${CLONE_TEMPLATE_BUCKET}"
stacks[infra-stack]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/infra-stack/RootStack.yaml ${COMMON_PARAMETERS} ParameterKey=SSLCertificateID,ParameterValue=${SSLCertificateID}"

# Loop through each stack and create/update the change set
for stack_name in "${!stacks[@]}"; do
  IFS=' ' read -r -a stack_params <<< "${stacks[$stack_name]}"
  template_url=${stack_params[0]}
  parameters=${stacks[$stack_name]#"$template_url "}
  create_change_set "${stack_name}" "${STACK_ENV}" "${template_url}" "${parameters}"
done
