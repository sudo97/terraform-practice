terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

resource "aws_lambda_function" "generate_website" {
  filename         = "lambda_function_payload.zip"
  function_name    = "generate-website"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  source_code_hash = filebase64sha256("lambda_function_payload.zip")
  runtime          = "nodejs18.x"

  environment {
    variables = {
      SOURCE_BUCKET      = aws_s3_bucket.source_bucket.bucket
      DESTINATION_BUCKET = aws_s3_bucket.destination_bucket.bucket
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "lambda_exec_policy" {
  name = "lambda_exec_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.source_bucket.bucket}/*",
          "arn:aws:s3:::${aws_s3_bucket.source_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.destination_bucket.bucket}/*"
        ]
      }
    ]
  })
}

# API Gateway

resource "aws_api_gateway_rest_api" "api" {
  name        = "generate_website_api"
  description = "API Gateway for triggering the generate_website lambda function"
}

resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "generate"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.generate_website.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_website.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

output "api_gateway_invoke_url" {
  value = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.region}.amazonaws.com/${var.stage}/generate"
}

output "api_id" {
  value = aws_api_gateway_rest_api.api.id
}

output "resource_id" {
  value = aws_api_gateway_resource.resource.id
}

variable "region" {
  default = "us-east-1"
}

variable "stage" {
  default = "dev"
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.stage
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on  = [aws_api_gateway_integration.integration]
  rest_api_id = aws_api_gateway_rest_api.api.id
}

# Buckets

resource "aws_s3_bucket" "source_bucket" {
}

output "source_bucket_name" {
  value = aws_s3_bucket.source_bucket.id
}

# resource "aws_s3_bucket_acl" "source_bucket_acl" {
#   bucket = aws_s3_bucket.source_bucket.id
#   acl    = "private"
# }

resource "aws_s3_bucket" "destination_bucket" {
}

output "destination_bucket_name" {
  value = aws_s3_bucket.destination_bucket.id
}

# resource "aws_s3_bucket_acl" "destination_bucket_acl" {
#   bucket = aws_s3_bucket.destination_bucket.id
#   acl    = "private"
# }