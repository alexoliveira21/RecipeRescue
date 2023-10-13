#!/bin/bash

# Configuration
LAMBDA_FUNCTION_NAME="RecipeRescueIngestion"
LAMBDA_FUNCTION_NAME2="RecipeRescueOutput"
LAMBDA_ROLE_NAME="RecipeRescueLambdaRole"
S3_BUCKET="code-deploy-bucket-alexandre-oliveira"

# Create the S3 bucket if it doesn't exist
if ! aws s3api head-bucket --bucket $S3_BUCKET 2>/dev/null; then
    aws s3api create-bucket --bucket $S3_BUCKET 
fi

# Create the "package" directory if it doesn't exist
mkdir -p package

# Install dependencies and create a deployment package
pip install -r lambda/requirements.txt -t ./package
cp -r lambda/* ./package

# Zip the package
zip -r deployment-package.zip ./package/*

# Upload the code to S3
aws s3 cp deployment-package.zip s3://$S3_BUCKET/


# Check if the IAM role already exists
if ! aws iam get-role --role-name $LAMBDA_ROLE_NAME > /dev/null 2>&1
then
    # Create the Lambda execution role
    LAMBDA_ROLE_ARN=$(aws iam create-role \
      --role-name $LAMBDA_ROLE_NAME \
      --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Principal": {
              "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
          }
        ]
      }' \
      --output text --query 'Role.Arn'
    )

    # Attach the Lambda execution policy to the role
    aws iam attach-role-policy --role-name $LAMBDA_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
else
    # Get the IAM role's ARN
    LAMBDA_ROLE_ARN=$(aws iam get-role --role-name $LAMBDA_ROLE_NAME --query 'Role.Arn' --output text)
fi

# Check if the Lambda function already exists
if aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME > /dev/null 2>&1
then
  # Update the Lambda function with new code
  aws lambda update-function-code \
    --function-name $LAMBDA_FUNCTION_NAME \
    --role $LAMBDA_ROLE_ARN \
    --handler "initiate_text_extraction.lambda_handler" \
    --s3-bucket $S3_BUCKET \
    --s3-key deployment-package.zip
else
  # Create the Lambda function
  aws lambda create-function \
    --function-name $LAMBDA_FUNCTION_NAME \
    --role $LAMBDA_ROLE_ARN \
    --runtime python3.8 \
    --handler "initiate_text_extraction.lambda_handler" \
    --code S3Bucket=$S3_BUCKET,S3Key=deployment-package.zip
fi

# Check if the Lambda function already exists
if aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME2 > /dev/null 2>&1
then
  # Update the Lambda function with new code
  aws lambda update-function-code \
    --function-name $LAMBDA_FUNCTION_NAME2 \
    --role $LAMBDA_ROLE_ARN \
    --handler "translate_text_extraction.lambda_handler" \
    --s3-bucket $S3_BUCKET \
    --s3-key deployment-package.zip
else
  # Create the Lambda function
  aws lambda create-function \
    --function-name $LAMBDA_FUNCTION_NAME2 \
    --role $LAMBDA_ROLE_ARN \
    --runtime python3.8 \
    --handler "translate_text_extraction.lambda_handler" \
    --code S3Bucket=$S3_BUCKET,S3Key=deployment-package.zip
fi