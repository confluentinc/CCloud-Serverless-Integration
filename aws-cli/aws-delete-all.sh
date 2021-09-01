#! /bin/bash

. ./configs.sh

if test ! -f ~/.aws/credentials; then
   echo "AWS credentials are required please set up credentials for your account"
   exit 1
fi

SET_PROFILE=$(grep "$PROFILE" < ~/.aws/credentials)
if [[ $SET_PROFILE == "" ]]; then
  echo "Profile ${PROFILE} not found in the AWS configurations, check and fix in the configs.sh file"
  exit 1
fi



# clean out results file from any previous runs
echo "Cleaning out aws command response file aws-results.out"
true > aws-results.out


read -p "This will delete all the AWS resources you created.  Enter y if you are sure n to cancel " -n 2 delete
      if [[  "${delete}" == 'y' ]]; then
        echo ""
        echo "OK deleting everything now"

        echo "Get the UUID of the event source mapping so we can delete it"
        UUID=$(aws lambda list-event-source-mappings --profile "${PROFILE}" --region "${REGION}" \
        --function-name "${FUNCTION_NAME}" | jq -r '.EventSourceMappings | .[0] | .UUID')

        echo "Deleting the event source mapping with UUID [${UUID}]"
        aws lambda delete-event-source-mapping --profile "${PROFILE}" --region "${REGION}" --uuid "${UUID}"  | tee -a aws-results.out

        echo "Deleting with the Lambda instance "
        aws lambda delete-function --profile "${PROFILE}" --region "${REGION}" \
            --function-name "${FUNCTION_NAME}" | tee -a aws-results.out

        echo "Deleting the in-line policy"
        aws iam delete-role-policy --profile "${PROFILE}" --region "${REGION}"\
            --role-name "${ROLE_NAME}" --policy-name "${POLICY_NAME}" | tee -a aws-results.out

        echo "Deleting the role"
        aws iam delete-role --profile "${PROFILE}" \
            --region "${REGION}" --role-name "${ROLE_NAME}" | tee -a aws-results.out

        echo "Deleting the secret instance, this is a hard delete with no recovery"
        aws secretsmanager delete-secret --profile "${PROFILE}" --region "${REGION}" \
            --secret-id "${CREDS_NAME}" --force-delete-without-recovery  | tee -a aws-results.out
      else
        echo
        echo "Will not delete and exit now..."
      fi

