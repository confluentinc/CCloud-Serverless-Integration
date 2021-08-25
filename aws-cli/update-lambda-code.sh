#! /bin/zsh

. ./configs.sh

# If you need to update the Lambda
# Make the desired code changes
# run ./gradlew clean build buildZip to create the distro
# then run this script

# clean out results file from any previous runs
true > aws-results.json

echo "Update the Lambda code"
aws lambda update-function-code --profile "${PROFILE}" --region "${REGION}" \
    --function-name "${FUNCTION_NAME}" \
    --zip-file fileb://../build/distributions/confluent-lambda-serverless-1.0-SNAPSHOT.zip | tee aws-results.json



