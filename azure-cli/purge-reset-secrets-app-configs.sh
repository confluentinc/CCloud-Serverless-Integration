#! /bin/bash

if [ ! -f "azure-app-settings.json" ]; then
  echo "Missing required config file azure-app-settings.json"
  exit 1
fi

. ./azure-configs.sh

OLD_KEYS=$(az keyvault secret list --vault-name "$KEY_VAULT" | jq -r '.[].name')

if [ -n "$OLD_KEYS" ]; then
  echo "Retrieved previous secret keys for deleting"
  echo "${OLD_KEYS}"
  echo "Removing the refs for secrets in applications"

  for functionapp in $(az resource list \
                       --resource-group "$RESOURCE_GROUP" \
                       --resource-type Microsoft.Web/sites | jq -r '.[] | .name'); do

    echo "Removing the refs for secrets in application $functionapp"
    az functionapp config appsettings delete \
      --name "$functionapp" \
      --resource-group "$RESOURCE_GROUP" \
      --setting-names $OLD_KEYS
    done



  echo "Deleting all secrets"
  for key in $OLD_KEYS; do
    echo "Deleting ${key}"
    az keyvault secret delete --name "$key" --vault-name "${KEY_VAULT}"
  done

  echo "Waiting for all deleted keys to sync"
  DELETED_KEYS=$(az keyvault secret list-deleted --vault-name "${KEY_VAULT}"  | jq -r '.[].name')

  while [[ "$OLD_KEYS" != "$DELETED_KEYS" ]]; do
        sleep 30
        echo "Checking if delete fully synced"
        DELETED_KEYS=$(az keyvault secret list-deleted --vault-name "${KEY_VAULT}"  | jq -r '.[].name')
  done

  echo "Delete completed, now purging the keys"
  for key in $OLD_KEYS; do
    echo "Purging ${key}"
    az keyvault secret purge --name "$key" --vault-name "${KEY_VAULT}"
  done
    
  echo "Waiting for purge to sync"
  sleep 60
  PURGED_KEYS=$(az keyvault secret list-deleted --vault-name "${KEY_VAULT}"  | jq -r '.[].name')
  while [[ -n "$PURGED_KEYS" ]]; do
    sleep 30
    echo "Checking for purge sync again"
    PURGED_KEYS=$(az keyvault secret list-deleted --vault-name "${KEY_VAULT}"  | jq -r '.[].name')
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

for functionapp in $(az resource list \
                     --resource-group "$RESOURCE_GROUP" \
                     --resource-type Microsoft.Web/sites | jq -r '.[] | .name'); do

  for k in $(az keyvault secret list --vault-name "$KEY_VAULT" | jq -r '.[].name'); do
    echo "Setting App setting to latest for ${k} in ${functionapp}"
    az functionapp config appsettings set \
      --name "$functionapp" \
      --resource-group "$RESOURCE_GROUP" \
      --settings "${k}=@Microsoft.KeyVault(SecretUri=https://confluent-cloud-keyvault.vault.azure.net/secrets/${k})"
   done
done

