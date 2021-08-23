#! /bin/zsh

# These variables serve to fill the variables
# in the scripts for use in running the various
# commands for building the Lambda

# Update the variables with angle brackets with the
# appropriate information from either your AWS account
# or CCloud. Feel free to update the names of the other
# variables as desired. 
export PROFILE="<AWS PROFILE>"
export REGION="<REGION TO USE>"
export BOOTSTRAP_SERVERS="<BOOTSTRAP SERVERS CONFIG>"

export ROLE_NAME="ccloud-lambda"
export POLICY_NAME="ccloud-lambda-policy"
export CREDS_NAME="CCloudLambdaCreds"
export FUNCTION_NAME="CCloudLambdaIntegration"
