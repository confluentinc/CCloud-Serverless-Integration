#! /bin/zsh

#  Update the configs.orig.sh file with
#  any variables you want to provide
#  leave any empty you dont want to specify

. ./configs.sh

# clean out results file from any previous runs
true > aws-results.json

echo "Create the AWS secrets config to hold connection information"
aws secretsmanager create-secret --profile "${PROFILE}" --region "${REGION}" \
              --name "${CREDS_NAME}" \
              --description "Credentials for connecting to Kafka and SR in CCloud" \
              --secret-string file://aws-ccloud-creds.json  | tee -a aws-results.json

echo "Create the role needed for the lambda"
aws iam create-role --profile "${PROFILE}" \
  --region "${REGION}" --role-name "${ROLE_NAME}" \
  --assume-role-policy-document  file://trust-policy.json | tee -a aws-results.json

echo "Add policy file inline (inline policy means other roles can't reuse the policy by AWS arn)"
aws iam put-role-policy --profile "${PROFILE}" --region "${REGION}" \
  --role-name "${ROLE_NAME}" --policy-name "${POLICY_NAME}" \
  --policy-document file://lambda-and-security-manager-policy.json | tee -a aws-results.json

echo "Create the lambda"
aws lambda  create-function --profile "${PROFILE}" --region "${REGION}" \
  --function-name "${FUNCTION_NAME}" \
  --memory-size 512 \
  --zip-file fileb://../build/distributions/confluent-lambda-serverless-1.0-SNAPSHOT.zip \
  --handler io.confluent.developer.CCloudRecordHandler::handleRequest \
  --runtime java11  --role arn:aws:iam::343223495109:role/"${ROLE_NAME}" | tee -a aws-results.json

echo "Adding a CCloud topic as an event source "
aws lambda create-event-source-mapping --profile "${PROFILE}" --region "${REGION}" \
    --topics lambda-test-input \
    --source-access-configuration Type=BASIC_AUTH,URI=arn:aws:secretsmanager:us-west-2:343223495109:secret:"${CREDS_NAME}" \
    --function-name arn:aws:lambda:us-west-2:343223495109:function:"${FUNCTION_NAME}" \
    --self-managed-event-source '{"Endpoints":{"KAFKA_BOOTSTRAP_SERVERS":["pkc-pgq85.us-west-2.aws.confluent.cloud:9092"]}}'


