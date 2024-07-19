#!/bin/bash

# Source the common parameters file
source ./parameters/common_parameters.sh
source ./parameters/helper_stack_parameters.sh
source ./parameters/network_stack_parameters.sh
source ./parameters/infra_stack_parameters.sh

# Initialize a variable to accumulate messages
NOTIFICATION_MESSAGES=""

# Function to create or update a change set for a given stack
create_change_set() {
  stack_name=$1
  stack_env=$2
  template_url=$3
  parameters=$4

  full_stack_name="${stack_name}-stack-${stack_env}"
  change_set_name="${stack_name}-stack-changeset"

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
      accumulate_message "${full_stack_name}" "${change_set_status}"
    fi
    
  else
    echo "Stack ${full_stack_name} does not exist."
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

# Define stacks and their specific parameters
declare -A stacks
stacks[helper]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/helper-stack/RootStack.yaml ./parameters/common_parameters.sh ./parameters/helper_stack_parameters.sh"
stacks[network]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/network-stack/RootStack.yaml ./parameters/network_stack_parameters.sh"
stacks[infra]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/infra-stack/RootStack.yaml ./parameters/common_parameters.sh ./parameters/infra_stack_parameters.sh"

# Loop through each stack and create/update the change set
for stack_name in "${!stacks[@]}"; do
  IFS=' ' read -r -a stack_params <<< "${stacks[$stack_name]}"
  template_url=${stack_params[0]}
  parameter_file=${stack_params[1]}

  # Source the specific parameter file
  source ./${parameter_file}

  # Combine common parameters with stack-specific parameters
  if [ "${stack_name}" == "helper" ]; then
    parameters="${COMMON_PARAMETERS} ${HELPER_STACK_PARAMETERS}"
  elif [ "${stack_name}" == "network" ]; then
    parameters="${NETWORK_STACK_PARAMETERS}"
  elif [ "${stack_name}" == "infra" ]; then
    parameters="${COMMON_PARAMETERS} ${INFRA_STACK_PARAMETERS}"
  fi

  create_change_set "${stack_name}" "${STACK_ENV}" "${template_url}" "${parameters}"
done

# Send the accumulated notification to Microsoft Teams
send_notification
