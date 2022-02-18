#! /bin/zsh

# These variables serve to fill the variables
# in the scripts for use in running the various
# commands for building the Lambda

# Update the variables with angle brackets with the
# appropriate information from either your AWS account
# or CCloud. Feel free to update the names of the other
# variables as desired.

export REGION="eastus"
export RESOURCE_GROUP="confluentazuresinkconnec"
export SINK_FUNCTION_NAME="ConfluentAzureSinkConnectorFunctionApp"
export DIRECT_FUNCTION_NAME="AzureKafkaDirectFunctionApp"
export KEY_VAULT="confluent-cloud-keyvault"
