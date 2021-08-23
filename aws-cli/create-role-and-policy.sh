#! /bin/zsh

. ./configs.sh

# This script is used to create an execution role for the
# Lambda.  It also attaches a policy file to the role
# with the permissions the Lambda has when running.
# You only need to run this script once.  After that
# you can refer to the role by name

# clean out results file from any previous runs
true > aws-results.json

echo "Create the role needed for the lambda"
aws iam create-role --profile "${PROFILE}" \
  --region "${REGION}" --role-name "${ROLE_NAME}" \
  --assume-role-policy-document  file://trust-policy.json | tee aws-results.json

echo "Add policy file inline (inline policy means other roles can't reuse the policy by AWS arn)"
aws iam put-role-policy --profile "${PROFILE}" --region "${REGION}" \
  --role-name "${ROLE_NAME}" --policy-name "${POLICY_NAME}" \
  --policy-document file://lambda-and-security-manager-policy.json | tee -a aws-results.json



