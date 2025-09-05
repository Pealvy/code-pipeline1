provider "aws" {
  region = "us-east-1" 
}
 
# Request bucket (input JSON)
resource "aws_s3_bucket" "request_bucket" {
  bucket = "achiaa-translate-requests"
  force_destroy = true
}
 
# Response bucket (output JSON)
resource "aws_s3_bucket" "response_bucket" {
  bucket = "achiaa-translate-responses"
  force_destroy = true
}
 
# Lifecycle policy for request bucket
resource "aws_s3_bucket_lifecycle_configuration" "request_lifecycle" {
  bucket = aws_s3_bucket.request_bucket.id
 
  rule {
    id     = "expire-objects"
    status = "Enabled"
 
    filter {} # Expire all objects
 
    expiration {
      days = 7
    }
  }
}
 
# Lifecycle policy for response bucket
resource "aws_s3_bucket_lifecycle_configuration" "response_lifecycle" {
  bucket = aws_s3_bucket.response_bucket.id
 
  rule {
    id     = "expire-objects"
    status = "Enabled"
 
    filter {} # Expire all objects
 
    expiration {
      days = 30
    }
  }
}
 
# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "achiaa-translate-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}
 
# IAM Policy for Translate + S3
resource "aws_iam_role_policy" "lambda_policy" {
  name = "achiaa-translate-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "translate:TranslateText",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}
 
# Package Lambda (expects zip file in ./lambda)
resource "aws_lambda_function" "translate_lambda" {
  function_name = "achiaa-translate-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda.lambda_handler"
  runtime       = "python3.10"
 
  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")
 
  environment {
    variables = {
      RESPONSE_BUCKET = aws_s3_bucket.response_bucket.bucket
    }
  }
}
 
# S3 → Lambda Trigger
resource "aws_s3_bucket_notification" "request_trigger" {
  bucket = aws_s3_bucket.request_bucket.id
 
  lambda_function {
    lambda_function_arn = aws_lambda_function.translate_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".json"
  }
 
  depends_on = [
   aws_lambda_function.translate_lambda,
    aws_lambda_permission.allow_s3
 ]
}
 
# Allow S3 to invoke Lambda
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.translate_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.request_bucket.arn
}