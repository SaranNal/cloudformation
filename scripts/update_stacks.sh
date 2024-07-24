#!/bin/bash

# Print the current directory for debugging
echo "Current directory: $(pwd)"

# Print the STACK_ENV to verify it is being set correctly
echo "STACK_ENV is set to: ${STACK_ENV}"

# Print the Environment to verify it is being set correctly
echo "Environment is set to: ${Environment}"
echo "StackBucketName is set to: ${CLONE_TEMPLATE_BUCKET}"
echo "PublicSubnets is set to: ${PublicSubnets}"
echo "PrivateSubnets is set to: ${PrivateSubnets}"

# Function to replace environment variables in a JSON file
replace_env_variables() {
  local json_file=$1
  envsubst < "$json_file" > "${json_file}.tmp" && mv "${json_file}.tmp" "$json_file"
}

# Function to load parameters from a JSON file
load_parameters_from_json() {
  local json_file=$1
  
  if [ ! -f "${json_file}" ]; then
    echo "Error: JSON file ${json_file} does not exist."
    exit 1
  fi
  
  # Replace environment variables in the JSON file
  replace_env_variables "${json_file}"

  # Determine which type of parameter file it is and format accordingly
  case "${json_file}" in
    *common_parameters.json)
      jq -r '.COMMON_PARAMETERS[] | "ParameterKey=\(.ParameterKey),ParameterValue=\(.ParameterValue)"' "${json_file}"
      ;;
    *helper_stack_parameters.json)
      jq -r '.HELPER_STACK_PARAMETERS[] | "ParameterKey=\(.ParameterKey),ParameterValue=\(.ParameterValue)"' "${json_file}"
      ;;
    *infra_stack_parameters.json)
      jq -r '.INFRA_STACK_PARAMETERS[] | if (.ParameterValue | type) == "array" then "ParameterKey=\(.ParameterKey),ParameterValue=\(.ParameterValue | join(","))" else "ParameterKey=\(.ParameterKey),ParameterValue=\(.ParameterValue)" end' "${json_file}"
      ;;
    *network_stack_parameters.json)
      jq -r '.NETWORK_STACK_PARAMETERS[] | "ParameterKey=\(.ParameterKey),ParameterValue=\(.ParameterValue)"' "${json_file}"
      ;;
    *)
      echo "Error: JSON file ${json_file} has an unknown format."
      exit 1
      ;;
  esac
}

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
  WEBHOOK_URL="https://knackforge.webhook.office.com//webhookb2/4200c843-c469-46b9-a7e0-3c059c22e68c@196eed21-c67a-4aae-a70b-9f97644d5d14/IncomingWebhook/d073338c8ee14403873ff0900646574f/73c1d036-08b9-4dd3-8346-afa964097b0a"
  PAYLOAD="{\"text\": \"${NOTIFICATION_MESSAGES}\"}"
  
  curl -H "Content-Type: application/json" -d "${PAYLOAD}" "${WEBHOOK_URL}"
}

# Define stacks and their specific parameter files
declare -A stacks
stacks[helper]="https://test-cloudformation-template-current-stack.s3.amazonaws.com/helper-stack/RootStack.yaml ./parameters/common_parameters.json ./parameters/helper_stack_parameters.json"
stacks[network]="https://test-cloudformation-template-current-stack.s3.amazonaws.com/network-stack/RootStack.yaml ./parameters/network_stack_parameters.json"
stacks[infra]="https://test-cloudformation-template-current-stack.s3.amazonaws.com/infra-stack/RootStack.yaml ./parameters/common_parameters.json ./parameters/infra_stack_parameters.json"

# Loop through each stack and create/update the change set
for stack_name in "${!stacks[@]}"; do
  IFS=' ' read -r -a stack_params <<< "${stacks[$stack_name]}"
  template_url=${stack_params[0]}
  parameter_files=("${stack_params[@]:1}")

  # Combine parameters from all specified JSON files
  parameters=""
  for param_file in "${parameter_files[@]}"; do
    echo "Loading parameters from ${param_file}..."
    parameters+=$(load_parameters_from_json "${param_file}")" "
  done

  create_change_set "${stack_name}" "${STACK_ENV}" "${template_url}" "${parameters}"
done

# Send the accumulated notification to Microsoft Teams
send_notification
