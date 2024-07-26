#!/bin/bash

echo "${parameters}"

# Define parameters
STACK_ENV=$1
Environment=$2
ProjectName=$3
CodeStarConnectionID=$4
CLONE_TEMPLATE_BUCKET=$5
S3LogBucket=$6
SSLCertificateID=$7

# Function to update a CloudFormation stack
update_stack() {
  local stack_name=$1
  local template_url=$2
  local parameters_file=$3
  local change_set_name="${stack_name}-changeset"

  # Check if stack exists
  echo "Checking changes for ${stack_name}..."
  if aws cloudformation describe-stacks --stack-name "${stack_name}-${STACK_ENV}" >/dev/null 2>&1; then
    echo "Updating ${stack_name}..."
    aws cloudformation create-change-set --stack-name "${stack_name}-${STACK_ENV}" \
                                         --template-url "${template_url}" \
                                         --change-set-name "${change_set_name}" \
                                         --capabilities CAPABILITY_NAMED_IAM \
                                         --include-nested-stacks \
                                         --parameters file://dev/parameters/${stack_name}-parameters.json
    aws cloudformation wait change-set-create-complete --stack-name "${stack_name}-${STACK_ENV}" --change-set-name "${change_set_name}"
    change_set_status=$(aws cloudformation describe-change-set --stack-name "${stack_name}-${STACK_ENV}" --change-set-name "${change_set_name}" --query 'Status' --output text)

    # Accumulate message
    accumulate_message "${stack_name}-${STACK_ENV}" "${change_set_status}"
  else
    echo "${stack_name}-stage does not exist, skipping."
  fi
}

# Function to accumulate messages to be sent to Microsoft Teams
accumulate_message() {
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

  NOTIFICATION_MESSAGES+="${MESSAGE}<br>Status: **${STATUS}**.<br>CloudFormation Stack URL: ${STACK_URL}<br><br>"
}

# Function to send the accumulated notification to Microsoft Teams
send_notification() {
  WEBHOOK_URL="https://knackforge.webhook.office.com/webhookb2/93eea688-6368-4c47-8d54-92a7ba364b30@196eed21-c67a-4aae-a70b-9f97644d5d14/IncomingWebhook/a5fab871a77e4c3ab1f770a1ba50c18f/73c1d036-08b9-4dd3-8346-afa964097b0a"
  PAYLOAD="{\"text\": \"${NOTIFICATION_MESSAGES}\"}"
  
  curl -H "Content-Type: application/json" -d "${PAYLOAD}" "${WEBHOOK_URL}"
}

# File paths to parameters
common_parameters_file="dev/parameters/common-parameters.json"
helper_stack_parameters_file="dev/parameters/helper-stack-parameters.json"
network_stack_parameters_file="dev/parameters/network-stack-parameters.json"
infra_stack_parameters_file="dev/parameters/infra-stack-parameters.json"

# Update stacks
update_stack "helper-stack" "https://test-cloudformation-template-clone-stack.s3.amazonaws.com/helper-stack/RootStack.yaml" "${helper_stack_parameters_file}"
update_stack "network-stack" "https://test-cloudformation-template-clone-stack.s3.amazonaws.com/network-stack/RootStack.yaml" "${network_stack_parameters_file}"
update_stack "infra-stack" "https://test-cloudformation-template-clone-stack.s3.amazonaws.com/infra-stack/RootStack.yaml" "${infra_stack_parameters_file}"

# Send the accumulated notification to Microsoft Teams
send_notification
