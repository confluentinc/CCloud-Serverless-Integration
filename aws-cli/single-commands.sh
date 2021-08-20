#! /bin/zsh

. ./configs.sh

aws lambda update-function-code --profile "${PROFILE}" --region "${REGION}" \
    --function-name ccloudStockTradeFunction \
    --zip-file fileb://../build/distributions/confluent-lambda-serverless-1.0-SNAPSHOT.zip