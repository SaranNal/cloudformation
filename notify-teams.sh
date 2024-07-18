#!/bin/bash

notify_teams() {
  STACK_NAME=$1
  STATUS=$2
  STACK_URL="https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks?filteringText=&filteringStatus=active&viewNested=false"
  
  if [ "${STATUS}" == "CREATE_COMPLETE" ]; then
    MESSAGE="Some new changes have occurred in ${STACK_NAME}. Please review and approve to execute."
  elif [ "${STATUS}" == "FAILED" ]; then
    MESSAGE="No changes detected in ${STACK_NAME}."
  else
    MESSAGE="Unknown status ${STATUS} for stack ${STACK_NAME}."
  fi

  WEBHOOK_URL="https://knackforge.webhook.office.com/webhookb2/93eea688-6368-4c47-8d54-92a7ba364b30@196eed21-c67a-4aae-a70b-9f97644d5d14/IncomingWebhook/a5fab871a77e4c3ab1f770a1ba50c18f/73c1d036-08b9-4dd3-8346-afa964097b0a"
  PAYLOAD="{\"text\": \"${MESSAGE}<br>Status: ${STATUS}.<br>CloudFormation Stack URL: ${STACK_URL}\"}"
  
  curl -H "Content-Type: application/json" -d "${PAYLOAD}" "${WEBHOOK_URL}"
}

if [ "$#" -gt 0 ]; then
  notify_teams "$@"
fi

# if [ "$#" -ne 2 ]; then
#   echo "Usage: $0 STACK_NAME STATUS"
#   exit 1
# fi

# notify_teams $1 $2