# Confluent Cloud Lambda Serverless Integration

### Prerequisites
* Java 11
* Gradle
* A user account in [Confluent Cloud](https://www.confluent.io/confluent-cloud/tryfree/)
* Local installation of [Confluent Cloud](https://docs.confluent.io/ccloud-cli/current/install.html) CLI v1.36.0 or later
* A user account in AWS

NOTE: The steps listed here are manual, but AWS CLI commands will be coming soon.  Also,
the directions here are assuming the user is external to Confluent.

Here are instructions for getting started with Confluent Cloud and Lambda functions.  The instructions for various cloud providers
will not be extensive, but links to relevant documentation will be provided.

* Log into AWS console and select the IAM service 
  * Create a policy using `src/main/resources/lambda-and-security-manager-policy.json` as an example
  * Create a role i.e. `my-lambda-role` and add the policy you just created to it.  This step is necessary as you'll assign a role to your lambda function and the policy file establishes the permissions of what your lambda function is allowed to do.  For more information take a look at [Policies and Permissions](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html).  
  
* Now select the Lambda service in the AWS console
  * Click on `Create function`
  * Give the function a name
  * Select the runtime
  * Click on `Change default execution role` and select `Use an existing role` and add the role you created in the previous step
         
TODO complete the instructions