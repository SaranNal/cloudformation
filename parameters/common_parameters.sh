#!/bin/bash
# common_parameters.sh

STACK_ENV="dev"
Environment="dev"
ProjectName="saran"
CodeStarConnectionID="93b8e92b-c501-4fb7-a30d-487c138b6d46"
CLONE_TEMPLATE_BUCKET="my-clone-template-bucket"
# SSLCertificateID="c038183c-5752-4c8f-b992-4f5c166c8b14"
# S3LogBucket="saran-s3-access-logs"
COMMON_PARAMETERS="ParameterKey=Environment,ParameterValue=${Environment} ParameterKey=ProjectName,ParameterValue=${ProjectName} ParameterKey=CodeStarConnectionID,ParameterValue=${CodeStarConnectionID} ParameterKey=StackBucketName,ParameterValue=${CLONE_TEMPLATE_BUCKET}"
