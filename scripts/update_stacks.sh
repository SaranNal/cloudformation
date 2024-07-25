#!/bin/bash

# Load parameters from multiple JSON files
function load_parameters() {
  local json_files=("$@")
  local parameters=""
  
  for json_file in "${json_files[@]}"; do
    if [[ -f "$json_file" ]]; then
      # Correctly format parameters to avoid extra quotes
      parameters+=" $(jq -r '.[] | "\(.ParameterKey)=\(.ParameterValue)"' "$json_file")"
    else
      echo "Warning: File $json_file not found."
    fi
  done
  
  echo "$parameters"
}

# Define the environment variable
StackENV="$STACK_ENV"

# Define stack names, templates, and parameter files
declare -A stacks
stacks=( 
  ["helper-stack"]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/helper-stack/RootStack.yaml ./parameters/common_parameters.json ./parameters/helper_stack_parameters.json"
  ["network-stack"]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/network-stack/RootStack.yaml ./parameters/common_parameters.json ./parameters/network_stack_parameters.json"
  ["infra-stack"]="https://test-cloudformation-template-clone-stack.s3.amazonaws.com/infra-stack/RootStack.yaml ./parameters/common_parameters.json ./parameters/infra_stack_parameters.json"
)

# Iterate over stacks and update them
for stack in "${!stacks[@]}"; do
  echo "Checking changes for ${stack}..."
  
  if aws cloudformation describe-stacks --stack-name ${stack}-${StackENV} >/dev/null 2>&1; then
    echo "Updating ${stack}..."
    
    # Load parameters specific to the stack
    IFS=' ' read -r -a parameter_files <<< "${stacks[$stack]}"
    template_url="${parameter_files[0]}"
    parameters_files=("${parameter_files[@]:1}")
    parameters=$(load_parameters "${parameters_files[@]}")
    
    echo "Parameters to be used: $parameters"  # Debugging output

    # Create change set
    aws cloudformation create-change-set \
      --stack-name ${stack}-${StackENV} \
      --template-url $template_url \
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
