#! /bin/zsh

. ./configs.sh

# If you need to update the event source mapping you
# can use this script as a guide and adjust the fields as needed
# cf https://awscli.amazonaws.com/v2/documentation/api/latest/reference/lambda/update-event-source-mapping.html
# for all the possible options you can update

true > aws-results.out

echo "Get the UUID of the event source mapping for updating"
UUID=$(aws lambda list-event-source-mappings --profile "${PROFILE}" --region "${REGION}" \
     --function-name "${FUNCTION_NAME}" | jq -r '.EventSourceMappings | .[0] | .UUID')

echo "Update the event source mapping with UUID ${UUID}"
aws lambda update-event-source-mapping \
    --profile "${PROFILE}" --region "${REGION}" \
    --uuid  "${UUID}" \
    --batch-size 100  | tee aws-results.out


