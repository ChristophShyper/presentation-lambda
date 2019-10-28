locals {
  aws_region    = "eu-west-1"
  function_dir  = "lambda-source"
  function_name = "example"
  memory_size   = 128
  profile       = "demo"
  runtime       = "python3.7"
  s3_bucket     = "ksz-demo-example"
  s3_key        = "demo.zip"
  timeout       = 3
}

provider "aws" {
  region                  = local.aws_region
  shared_credentials_file = "$HOME/.aws/credentials"
  profile                 = local.profile
}

# get account id
data "aws_caller_identity" "default" {}

# get region name
data "aws_region" "default" {
  name = local.aws_region
}

data "aws_iam_policy_document" "assume_role" {
  policy_id = "lambda-assume-role"

  statement {
    sid     = "LambdaAssumeRole"
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
  }
}

data "aws_iam_policy_document" "demo" {
  policy_id = "lambda-function-policy"

  # write log group for lambda
  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:logs:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:log-group:${local.function_name}:*"
    ]
  }
}

data "archive_file" "demo" {
  type        = "zip"
  source_file = "${path.module}/../${local.function_dir}/index.py"
  output_path = "${path.module}/../${local.function_dir}/.dist/demo.zip"
}

resource "aws_s3_bucket" "demo" {
  acl    = "private"
  bucket = local.s3_bucket
}

resource "aws_iam_role" "demo" {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = "Policy for ${local.function_name} Lambda"
  name               = "${local.function_name}-role"
}

resource "aws_iam_role_policy" "demo" {
  policy = data.aws_iam_policy_document.demo.json
  role   = aws_iam_role.demo.id
}

resource "aws_s3_bucket_object" "demo" {
  bucket = aws_s3_bucket.demo.id
  key    = local.s3_key
  source = data.archive_file.demo.output_path
}

resource "aws_lambda_function" "demo" {
  description      = "Lambda example demo"
  function_name    = local.function_name
  handler          = "index.handler"
  memory_size      = local.memory_size
  role             = aws_iam_role.demo.arn
  runtime          = local.runtime
  s3_bucket        = aws_s3_bucket.demo.id
  s3_key           = local.s3_key
  source_code_hash = data.archive_file.demo.output_base64sha256
  timeout          = local.timeout

  environment {
    variables = {
      SOME_VAR = local.function_name
    }
  }
}
