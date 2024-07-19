#!/bin/bash

STACK_ENV=$1

check_and_execute_change_set() {
  local stack_name=$1

  echo "Checking and executing change set for ${stack_name}"
  CHANGE_SET_STATUS=$(aws cloudformation describe-change-set --stack-name ${stack_name}-${STACK_ENV} --change-set-name ${stack_name}-changeset --query 'Status' --output text)
  if [ "$CHANGE_SET_STATUS" = "CREATE_COMPLETE" ]; then
    aws cloudformation execute-change-set --stack-name ${stack_name}-${STACK_ENV} --change-set-name ${stack_name}-changeset
    aws cloudformation wait stack-update-complete --stack-name ${stack_name}-${STACK_ENV}
  else
    echo "No changes detected for ${stack_name} or change set creation failed."
    aws cloudformation delete-change-set --stack-name ${stack_name}-${STACK_ENV} --change-set-name ${stack_name}-changeset
  fi
}

check_and_execute_change_set "helper-stack"
check_and_execute_change_set "network-stack"
check_and_execute_change_set "infra-stack"
