#! /bin/zsh

. ./configs.sh

# If you need to update the Lambda
# Make the desired code changes
# run ./gradlew clean build buildZip to create the distro
# then run this script

echo "Delete the Lambda "
aws lambda delete-function --profile "${PROFILE}" --region "${REGION}" \
    --function-name "${FUNCTION_NAME}" \
    | tee -a aws-results.json


# TODO need to implement list-event-source-mappings to capture the UUID  integrate with jq
#   aws lambda list-event-source-mappings --profile "${PROFILE}" --region "${REGION}" --function-name "${FUNCTION_NAME}"
# TODO then with UUID captured we can use the delete-event-source-mapping
# aws lambda delete-event-source-mapping --profile "${PROFILE}" --region "${REGION}" \
#    --uuid 0b3f35ca-2822-46d3-91c3-09899270ef74

