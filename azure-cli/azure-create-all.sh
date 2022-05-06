#! /bin/bash

if [ ! -f "azure-app-settings.json" ]; then
  echo "Missing required config file azure-app-settings.json"
  exit 1
fi

. ./azure-configs.sh

echo "Select the application type to build"
select opt in kafka-direct-trigger sink-connector-trigger; do

  case $opt in
    sink-connector-trigger)
      APPLICATION_NAME=$SINK_FUNCTION_NAME
      PLAN_NAME=$SINK_FUNCTION_PLAN_NAME
      SKU=B1
      echo "${APPLICATION_NAME} selected"
      break
      ;;
     kafka-direct-trigger)
       APPLICATION_NAME=$DIRECT_FUNCTION_NAME
       PLAN_NAME=$DIRECT_FUNCTION_PLAN_NAME
       SKU=EP1
       echo "${APPLICATION_NAME} selected"
       break
       ;;
     *)
       echo "Invalid Entry $REPLY, please select 1 or 2"
       ;;
    esac
done

echo "Creating resource group"
az group create --location "$LOCATION" \
                --resource-group "$RESOURCE_GROUP"

echo "Pause 10 seconds for the group creation to sync"
sleep 10

echo "Creating a storage account"
az storage account create \
  --name "$STORAGE_ACCOUNT"\
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_RAGRS \
  --kind StorageV2

echo "Creating the key vault"
az keyvault create --location "$LOCATION" \
                    --name "$KEY_VAULT" \
                    --resource-group "$RESOURCE_GROUP"

echo "Creating the function plan"
if [ $APPLICATION_NAME == $DIRECT_FUNCTION_NAME ]; then
    az functionapp plan create \
       --name "$PLAN_NAME" \
       --resource-group "$RESOURCE_GROUP" \
       --location "$REGION" \
       --max-burst 100 \
       --sku $SKU
else
     az functionapp plan create \
        --name "$PLAN_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$REGION" \
        --sku $SKU
fi

echo "Pause 5 seconds for the function app plan to sync"
sleep 5

echo "Creating the function app $APPLICATION_NAME"
az functionapp create \
  --name "$APPLICATION_NAME" \
  --storage-account "$STORAGE_ACCOUNT" \
  --plan "$PLAN_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --functions-version 4

echo "Create the application zip for deployment"
./build_and_deploy_app.sh ${APPLICATION_NAME}

if [ $APPLICATION_NAME == $DIRECT_FUNCTION_NAME ]; then
    echo "Enable Runtime Scale Monitoring"
    az resource update --resource-group "$RESOURCE_GROUP" \
                       --name "$APPLICATION_NAME"/config/web --set properties.functionsRuntimeScaleMonitoringEnabled=1 \
                       --resource-type Microsoft.Web/sites
fi

echo "Stop app until credentials can be propagated"
az functionapp stop \
   --name "$APPLICATION_NAME" \
   --resource-group "$RESOURCE_GROUP"

echo "Get a system assigned ID"
PRINCIPAL_ID=$(az functionapp identity assign \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APPLICATION_NAME" | jq -r '.principalId')

echo "Add application system id to key-vault for access to credentials"
az keyvault set-policy --name  "$KEY_VAULT" \
   --resource-group "$RESOURCE_GROUP" \
   --object-id "$PRINCIPAL_ID" \
   --secret-permissions get list

echo "Set secrets for Confluent Cloud access"
./purge-reset-secrets-app-configs.sh

echo "Start the application"
az functionapp start \
   --name "$APPLICATION_NAME" \
   --resource-group "$RESOURCE_GROUP"