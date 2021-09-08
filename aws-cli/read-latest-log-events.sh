#! /bin/bash

. ./configs.sh

LATEST_LOG_STREAM_NAME=$(aws logs describe-log-streams\
   --profile "$PROFILE" --region "$REGION"\
   --order-by LastEventTime --descending\
   --log-group-name /aws/lambda/"$FUNCTION_NAME" | jq -r '.logStreams[0].logStreamName')

echo "Using latest log stream [$LATEST_LOG_STREAM_NAME]"

aws logs get-log-events --profile "$PROFILE" --region "$REGION"\
    --log-group-name /aws/lambda/"$FUNCTION_NAME"\
    --log-stream-name "$LATEST_LOG_STREAM_NAME"  | jq '.events[].message'

