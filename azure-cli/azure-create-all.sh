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
  --functions-version 4