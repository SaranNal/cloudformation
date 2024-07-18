#!/bin/bash
# helper_stack_parameters.sh

S3LogBucket="saran-s3-access-logs"
HELPER_STACK_PARAMETERS="ParameterKey=S3LogBucket,ParameterValue=${S3LogBucket}"
