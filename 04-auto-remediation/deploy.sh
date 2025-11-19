#!/usr/bin/env bash
set -euo pipefail
REGION=${1:-us-east-1}
FN=auto-remediate-s3-public

# Package (zip)
cd 04-auto-remediation/lambda_s3_public_block
zip -qr function.zip .
cd -

# Create role
aws iam create-role --role-name lambda-s3-remediate-role \
  --assume-role-policy-document '{
    "Version":"2012-10-17","Statement":[{
      "Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' || true
aws iam put-role-policy --role-name lambda-s3-remediate-role --policy-name inline \
  --policy-document file://04-auto-remediation/lambda_s3_public_block/policy.json

ROLE_ARN=$(aws iam get-role --role-name lambda-s3-remediate-role --query Role.Arn --output text)

# Create/update Lambda
aws lambda get-function --function-name $FN >/dev/null 2>&1 && EXISTS=1 || EXISTS=0
if [ "$EXISTS" -eq 0 ]; then
  aws lambda create-function --function-name $FN \
    --runtime python3.11 --handler handler.lambda_handler \
    --zip-file fileb://04-auto-remediation/lambda_s3_public_block/function.zip \
    --role $ROLE_ARN --timeout 60 --memory-size 256 --region $REGION
else
  aws lambda update-function-code --function-name $FN \
    --zip-file fileb://04-auto-remediation/lambda_s3_public_block/function.zip --region $REGION
fi

# EventBridge rule + target
RULE=ConfigNonCompliant
aws events put-rule --name $RULE --event-pattern file://04-auto-remediation/eventbridge-rule.json --region $REGION
aws events put-targets --rule $RULE --targets "Id"="1","Arn"="$(aws lambda get-function --function-name $FN --query Configuration.FunctionArn --output text --region $REGION)" --region $REGION

# Permission for EB to invoke Lambda
aws lambda add-permission --function-name $FN --statement-id evtrule --action lambda:InvokeFunction \
  --principal events.amazonaws.com --source-arn "$(aws events describe-rule --name $RULE --query Arn --output text --region $REGION)" --region $REGION || true

echo "Auto-remediation deployed in $REGION"
