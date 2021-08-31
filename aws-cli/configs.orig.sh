#! /bin/zsh

# These variables serve to fill the variables
# in the scripts for use in running the various
# commands for building the Lambda

# Update the variables with angle brackets with the
# appropriate information from either your AWS account
# or CCloud. Feel free to update the names of the other
# variables as desired. 
export PROFILE="<AWS PROFILE>"
export REGION="us-west-2"
export BOOTSTRAP_SERVERS="<BOOTSTRAP SERVERS CONFIG>"

export ROLE_NAME="CCloud-lambda-role"
export POLICY_NAME="CCloud-lambda-policy"
export CREDS_NAME="CCloudLambdaCredentials"
export FUNCTION_NAME="CCloudLambdaIntegrationFunction"
