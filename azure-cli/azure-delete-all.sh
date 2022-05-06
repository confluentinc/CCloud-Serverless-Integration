#! /bin/bash

if [ ! -f "azure-app-settings.json" ]; then
  echo "Missing required config file azure-app-settings.json"
  exit 1
fi

. ./azure-configs.sh

echo "Select the application to delete"
select opt in kafka-direct-trigger sink-connector-trigger; do

  case $opt in
    sink-connector-trigger)
      APPLICATION_NAME=$SINK_FUNCTION_NAME
      PLAN_NAME=$SINK_FUNCTION_PLAN_NAME
      echo "${APPLICATION_NAME} selected"
      break
      ;;
     kafka-direct-trigger)
       APPLICATION_NAME=$DIRECT_FUNCTION_NAME
       PLAN_NAME=$DIRECT_FUNCTION_PLAN_NAME
       echo "${APPLICATION_NAME} selected"
       break
       ;;
     *)
       echo "Invalid Entry $REPLY, please select 1 or 2"
       ;;
    esac
done


echo "Deleting the function app"

  az functionapp delete \
    --name "$APPLICATION_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --subscription "$SUBSCRIPTION_NAME"

echo "Now Deleting the function app plan, otherwise leaving the plan could incur more charges"
 az functionapp plan delete \
     --name "$PLAN_NAME" \
     --resource-group "$RESOURCE_GROUP" \
     --subscription "$SUBSCRIPTION_NAME" \
     --yes

echo "Removing the key vault first delete then purge"
az keyvault delete --name "$KEY_VAULT" \
                   --resource-group "$RESOURCE_GROUP"
echo "wait 10 seconds for delete to sync"
sleep 10

echo "Now purging key vault"
az keyvault purge --name "$KEY_VAULT" \
                   --location "$LOCATION"

 echo "Removing the storage account"
 az storage account delete \
          --name "$STORAGE_ACCOUNT" \
          --resource-group "$RESOURCE_GROUP" \
          --yes

 echo "Removing the resource group"
 az group delete --resource-group "$RESOURCE_GROUP" \
                 --yes