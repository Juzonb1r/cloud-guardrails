#!/bin/bash
set -e

REGION="us-east-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "===================================="
echo " Enabling AWS Config & Security Hub"
echo " REGION: $REGION"
echo " ACCOUNT: $ACCOUNT_ID"
echo "===================================="


###############################
# 1. CREATE CONFIG S3 BUCKET
###############################
BUCKET_NAME="config-logs-${ACCOUNT_ID}"

echo "Checking if bucket $BUCKET_NAME exists..."

if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Bucket does not exist. Creating..."
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"

    echo "Bucket created: $BUCKET_NAME"
else
    echo "Bucket already exists: $BUCKET_NAME"
fi


###############################
# 2. CREATE JSON FOR CONFIG RECORDER
###############################
cat > /tmp/config-recorder.json <<EOF
{
  "name": "default",
  "roleARN": "arn:aws:iam::${ACCOUNT_ID}:role/aws-service-role/config.amazonaws.com/AWSServiceRoleForConfig",
  "recordingGroup": {
      "allSupported": true,
      "includeGlobalResourceTypes": true
  }
}
EOF


###############################
# 3. CREATE JSON FOR DELIVERY CHANNEL
###############################
cat > /tmp/delivery-channel.json <<EOF
{
  "name": "default",
  "s3BucketName": "${BUCKET_NAME}"
}
EOF


###############################
# 4. CREATE JSON FOR SECURITY HUB STANDARDS
###############################
cat > /tmp/securityhub-standards.json <<EOF
[
  {
    "StandardsArn": "arn:aws:securityhub:${REGION}::standards/aws-foundational-security-best-practices/v/1.0.0"
  },
  {
    "StandardsArn": "arn:aws:securityhub:${REGION}::standards/cis-aws-foundations-benchmark/v/1.2.0"
  }
]
EOF


###############################
# 5. ENABLE AWS CONFIG
###############################
echo "=== Enabling AWS Config ==="

aws configservice put-configuration-recorder \
  --configuration-recorder file:///tmp/config-recorder.json

aws configservice put-delivery-channel \
  --delivery-channel file:///tmp/delivery-channel.json

aws configservice start-configuration-recorder \
  --configuration-recorder-name default

echo "=== AWS Config Enabled ==="


###############################
# 6. ENABLE SECURITY HUB
###############################
echo "=== Enabling Security Hub ==="

aws securityhub enable-security-hub \
  --region "$REGION" \
  || echo "Security Hub already enabled"

###############################
# 7. ENABLE SECURITY HUB STANDARDS
###############################
echo "=== Enabling Security Hub Standards ==="

aws securityhub batch-enable-standards \
    --region "$REGION" \
    --standards-subscription-requests file:///tmp/securityhub-standards.json \
    || echo "Standards already enabled"

echo "=== DONE ==="
