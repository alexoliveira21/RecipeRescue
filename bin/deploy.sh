#!/bin/bash

# Configuration
LAMBDA_FUNCTION_NAME="RecipeRescue"
LAMBDA_ROLE="arn:aws:iam::YourAccountID:role/YourLambdaRole"
S3_BUCKET="TestBucketAlexandreOliveira"

# Create the "package" directory if it doesn't exist
mkdir -p package

# Install dependencies and create a deployment package
pip install -r lambda/requirements.txt -t ./package
cp -r lambda/* ./package

# Zip the package
zip -r deployment-package.zip ./package/*

# Upload the code to S3
aws s3 cp deployment-package.zip s3://$S3_BUCKET/

# Check if the Lambda function already exists
if aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME > /dev/null 2>&1
then
  # Update the Lambda function with new code
  aws lambda update-function-code \
    --function-name $LAMBDA_FUNCTION_NAME \
    --s3-bucket $S3_BUCKET \
    --s3-key deployment-package.zip
else
  # Create the Lambda function
  aws lambda create-function \
    --function-name $LAMBDA_FUNCTION_NAME \
    --runtime python3.8 \
    --role $LAMBDA_ROLE \
    --handler handler_filename.handler_function \
    --code S3Bucket=$S3_BUCKET,S3Key=deployment-package.zip
fi