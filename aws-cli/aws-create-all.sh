#! /bin/zsh

. ./configs.sh

# clean out results file from any previous runs
echo "Cleaning out aws command response file aws-results.json"
true > aws-results.json


vared -p "Press Y/y to create the secrets manager answer n if you have it: " -c secret
      if [[  "${secret}" == 'y' ]]; then
        echo ""
        echo "OK Creating the secrets manager"
        ./create-secret.sh
      else
        echo " Got it, skipping the secrets manager, I'm assuming you have one"
      fi

vared -p "Press Y/y to create the role and policy file for the lambda: " -c role
      if [[ "${role}" == 'y' ]]; then
        echo
        echo "OK creating the role and policy file"
        ./create-role-and-policy.sh
      else
        echo " Got it, skipping the role and policy file, I'm assuming you have them"
      fi

vared -p "Press Y/y to create the Lambda and set the event source to a Kafka topic: " -c lambda
       if [[ "${lambda}" == 'y' ]]; then
         echo
         echo "Got it creating the Lambda and event source mapping now@"
         ./create-lambda.sh
       else
         echo "Ok Skipping the lambda but why are you running this script then?"
       fi