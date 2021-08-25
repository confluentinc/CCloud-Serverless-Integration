#! /bin/zsh

. ./configs.sh

# This command will create an AWS Secrets instance containing
# all of the credentials your Lambda will need to communicate
# with CCloud.
# Once you've created the secrets instance if you have updated the
# credentials, run the update-secret.sh script to get the new
# values into the secret manager
# This script depends on a JSON file 'aws-cli/aws-ccloud-creds.json'
# that you create by running ./gradlew propsToJson with your
# CCloud credentials saved to src/main/resources/confluent.properties (GitHub ignores confluent.properties)


echo "Create the AWS secrets config to hold connection information"
aws secretsmanager create-secret --profile "${PROFILE}" --region "${REGION}" \
              --name "${CREDS_NAME}" \
              --description "Credentials for connecting to Kafka and SR in CCloud" \
              --secret-string file://aws-ccloud-creds.json  | tee aws-results.json