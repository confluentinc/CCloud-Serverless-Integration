#!/bin/sh

. ./azure-configs.sh

echo "CD into project directory"
cd ../azure-kafka-direct || exit
if [ -f azure_app.zip ]; then
    echo "Removing previous ZIP file"
    rm azure_app.zip
fi

dotnet clean
dotnet build /p:DeployOnBuild=true /p:DeployTarget=Package;CreatePackageOnPublish=true
(cd obj/Debug/net6.0/PubTmp/Out && zip -rv ../../../../../azure_app.zip *)

echo "All done, going back to azure-cli directory"
cd ../azure-cli || exit

echo "Deploying the application"
az functionapp deployment source config-zip \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DIRECT_FUNCTION_NAME" \
    --src ../azure-kafka-direct/azure_app.zip