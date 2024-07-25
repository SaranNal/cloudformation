#!/bin/bash

# Load parameters from JSON files
function load_parameters() {
  local json_file="$1"
  echo $(jq -c '.[] | "\(.ParameterKey)=\(.ParameterValue)"' "$json_file" | tr '\n' ' ')
}

# Define the environment variable
StackENV="$STACK_ENV"

# Define stack names and templates
declare -A stacks
stacks=( 
  ["helper-stack"]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/helper-stack/RootStack.yaml ./parameters/common_parameters.json ./parameters/helper_stack_parameters.json"
  ["network-stack"]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/network-stack/RootStack.yaml ./parameters/network_stack_parameters.json"
  ["infra-stack"]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/infra-stack/RootStack.yaml ./parameters/common_parameters.json ./parameters/infra_stack_parameters.json"
)

# Iterate over stacks and update them
for stack in "${!stacks[@]}"; do
  echo "Checking changes for ${stack}..."
  
  if aws cloudformation describe-stacks --stack-name ${stack}-${StackENV} >/dev/null 2>&1; then
    echo "Updating ${stack}..."
    
    # Load parameters specific to the stack
    parameters_file="${stack}-parameters.json"
    parameters=$(load_parameters "$parameters_file")
    
    # Create change set
    aws cloudformation create-change-set \
      --stack-name ${stack}-${StackENV} \
      --template-url ${stacks[$stack]} \
      --change-set-name ${stack}-changeset \
      --capabilities CAPABILITY_NAMED_IAM \
      --include-nested-stacks \
      --parameters $parameters

    # Wait for change set creation to complete
    aws cloudformation wait change-set-create-complete --stack-name ${stack}-${StackENV} --change-set-name ${stack}-changeset
    
    # Describe the change set
    aws cloudformation describe-change-set --stack-name ${stack}-${StackENV} --change-set-name ${stack}-changeset
  else
    echo "${stack} does not exist."
  fi
done
