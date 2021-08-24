#! /bin/zsh

. ./configs.sh

# If you need to update the Lambda
# Make the desired code changes
# run ./gradlew clean build buildZip to create the distro
# then run this script

# clean out results file from any previous runs
true > aws-results.json

echo "Delete the Lambda "
aws lambda delete --profile "${PROFILE}" --region "${REGION}" \
    --function-name "${FUNCTION_NAME}" \
    | tee aws-results.json



