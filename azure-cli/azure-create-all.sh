#! /bin/bash

if [ ! -f "azure-app-settings.json" ]; then
  echo "Missing required config file azure-app-settings.json"
  exit 1
fi

. ./azure-configs.sh

echo "Creating the function app premium plan"
az functionapp plan create \
  --name "$PLAN_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$REGION" \
  --max-burst 100 \
  --sku EP1

echo "Pause 5 seconds for the functionapp plan to sync"
sleep 5

echo "Creating the functionapp $DIRECT_FUNCTION_NAME"
az functionapp create \
  --name "$DIRECT_FUNCTION_NAME" \
  --storage-account "$STORAGE_ACCOUNT" \
  --plan "$PLAN_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --functions-version 4                     ``

echo "Create the application zip for deployment"
./build_and_deploy_app.sh

echo "Enable Runtime Scale Monitoring"
az resource update --resource-group "$RESOURCE_GROUP" \
                   --name "$DIRECT_FUNCTION_NAME"/config/web --set properties.functionsRuntimeScaleMonitoringEnabled=1 \
                   --resource-type Microsoft.Web/sites

echo "Stop app until credentials can be propagated"
az functionapp stop \
   --name "$DIRECT_FUNCTION_NAME" \
   --resource-group "$RESOURCE_GROUP"

echo "Get a system assigned ID"
PRINCIPAL_ID=$(az functionapp identity assign \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DIRECT_FUNCTION_NAME" | jq -r '.principalId')

echo "Add application system id to key-vault for access to credentials"
az keyvault set-policy --name  "$KEY_VAULT" \
   --resource-group "$RESOURCE_GROUP" \
   --object-id "$PRINCIPAL_ID" \
   --secret-permissions get list

echo "Set secrets for Confluent Cloud access"
./purge-reset-secrets-app-configs.sh

echo "Start the application"
az functionapp start \
   --name "$DIRECT_FUNCTION_NAME" \
   --resource-group "$RESOURCE_GROUP"