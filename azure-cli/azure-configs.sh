#! /bin/zsh

# These variables serve to fill the variables
# in the scripts for use in running the various
# commands for building the Lambda

# Update the variables with angle brackets with the
# appropriate information from either your AWS account
# or CCloud. Feel free to update the names of the other
# variables as desired.

export REGION="eastus"
export RESOURCE_GROUP="ConfluentAzureGroup"

export SINK_FUNCTION_NAME="AzureSinkConnectorFunctionApp"
export SINK_FUNCTION_DIR="azure-ccloud-sink-connector"
export SINK_FUNCTION_ZIP="sink-connector-app.zip"
export SINK_FUNCTION_PLAN_NAME="AzureSinkConnectorPlan"

export DIRECT_FUNCTION_NAME="AzureKafkaDirectFunctionApp"
export DIRECT_FUNCTION_DIR="azure-ccloud-kafka-direct"
export DIRECT_FUNCTION_ZIP="kafka-direct-app.zip"
export DIRECT_FUNCTION_PLAN_NAME="AzureKafkaDirectPlan"

export KEY_VAULT="ConfluentSecretsKeyVault"
export STORAGE_ACCOUNT="confluentazurestorage"
export SUBSCRIPTION_NAME="Azure Subscription 1"
export LOCATION="eastus"
