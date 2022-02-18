#! /bin/bash

if [ ! -f "azure-app-settings.json" ]; then
  echo "Missing required config file azure-app-settings.json"
  exit 1
fi

. ./azure-configs.sh

OLD_KEYS=$(az keyvault secret list --vault-name "$KEY_VAULT" | jq -r '.[].name')

if [ -n "$OLD_KEYS" ]; then
  echo "Retrieved previous secret keys for deleting ${OLD_KEYS}"
  echo "Removing the refs for secrets in applications"
  az functionapp config appsettings delete \
     --name "$DIRECT_FUNCTION_NAME" \
     --resource-group "$RESOURCE_GROUP" \
     --setting-names $OLD_KEYS

  az functionapp config appsettings delete \
     --name "$SINK_FUNCTION_NAME" \
     --resource-group "$RESOURCE_GROUP" \
     --setting-names $OLD_KEYS

  echo "Deleting all secrets"
  for key in $OLD_KEYS; do
    echo "Deleting ${key}"
    az keyvault secret delete --name "$key" --vault-name "${KEY_VAULT}"
  done
  echo "Waiting 1 minute for the delete command to sync before purging"
  sleep 60

  echo "Now purging the keys"
  for key in $OLD_KEYS; do
    echo "Purging ${key}"
    az keyvault secret purge --name "$key" --vault-name "${KEY_VAULT}"
  done

else
  echo "No previous keys to delete"
fi

echo "Now setting all the updated secret values first the scalar values"
for k in $(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' azure-app-settings.json | grep -v 'json'); do
  CONFIG_NAME=$(echo "$k" | cut -d '=' -f 1)
  CONFIG_VALUE=$(echo "$k" | cut -d '=' -f 2)
  echo "Setting secret ${CONFIG_NAME}"
  az keyvault secret set --vault-name "$KEY_VAULT" --name "$CONFIG_NAME" --value "$CONFIG_VALUE"
done

echo "Now setting all the updated secret values for json config files"
for k in $(jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' azure-app-settings.json | grep 'json'); do
  CONFIG_NAME=$(echo "$k" | cut -d '=' -f 1)
  CONFIG_VALUE=$(echo "$k" | cut -d '=' -f 2)
  echo "Setting config ${CONFIG_NAME} with JSON file ${CONFIG_VALUE}"
  az keyvault secret set \
    --vault-name "$KEY_VAULT" \
    --name "$CONFIG_NAME" \
    --file "$CONFIG_VALUE"
done

echo "Now setting the application configs"
for k in $(az keyvault secret list --vault-name "$KEY_VAULT" | jq -r '.[].name'); do
  echo "Setting App setting to latest for ${k} in ${DIRECT_FUNCTION_NAME}"
  az functionapp config appsettings set \
    --name "$DIRECT_FUNCTION_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --settings "${k}=@Microsoft.KeyVault(SecretUri=https://confluent-cloud-keyvault.vault.azure.net/secrets/${k})"
    
  echo "Now in ${SINK_FUNCTION_NAME}"
  az functionapp config appsettings set \
    --name "$SINK_FUNCTION_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --settings "${k}=@Microsoft.KeyVault(SecretUri=https://confluent-cloud-keyvault.vault.azure.net/secrets/${k})";
  
done

