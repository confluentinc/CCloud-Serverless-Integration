#!/bin/sh

. ./azure-configs.sh

if [ -z $1 ];
 then
   echo "Select the application type to build"
   select opt in kafka-direct-trigger sink-connector-trigger; do

     case $opt in
       sink-connector-trigger)
         APPLICATION_NAME=$SINK_FUNCTION_NAME
         echo "${APPLICATION_NAME} selected"
         break
         ;;
        kafka-direct-trigger)
          APPLICATION_NAME=$DIRECT_FUNCTION_NAME
          echo "${APPLICATION_NAME} selected"
          break
          ;;
        *)
          echo "Invalid Entry $REPLY, please select 1 or 2"
          ;;
       esac
   done
else
  APPLICATION_NAME=$1
fi

if [ ${APPLICATION_NAME} == ${SINK_FUNCTION_NAME} ]; then
    ZIP_NAME=$SINK_FUNCTION_ZIP
    APPLICATION_DIR=$SINK_FUNCTION_DIR
elif [ ${APPLICATION_NAME} == ${DIRECT_FUNCTION_NAME} ]; then
     ZIP_NAME=$DIRECT_FUNCTION_ZIP
     APPLICATION_DIR=$DIRECT_FUNCTION_DIR
else
    echo "Unrecognized type ${APPLICATION_NAME}"
    exit
fi


echo "Using application type ${APPLICATION_NAME}, zip name ${ZIP_NAME}, and directory ${APPLICATION_DIR}"

echo "CD into project directory"
cd ../${APPLICATION_DIR} || exit
if [ -f ${ZIP_NAME} ]; then
    echo "Removing previous ZIP file"
    rm ${ZIP_NAME}
fi

dotnet clean
dotnet build /p:DeployOnBuild=true /p:DeployTarget=Package;CreatePackageOnPublish=true
(cd obj/Debug/net6.0/PubTmp/Out && zip -rv ../../../../../${ZIP_NAME} *)

echo "All done, going back to azure-cli directory"
cd ../azure-cli || exit

echo "Deploying the application"
az functionapp deployment source config-zip \
    --resource-group "$RESOURCE_GROUP" \
    --name "${APPLICATION_NAME}" \
    --src ../${APPLICATION_DIR}/${ZIP_NAME}