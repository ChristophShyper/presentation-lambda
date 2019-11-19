locals {
  aws_profile           = "demo"
  aws_region            = "eu-west-1"
  env_some_var          = "Value for my variable"
  function_dir          = "lambda-source"
  function_memory_limit = 128
  function_name         = "example"
  function_runtime      = "python3.7"
  function_timeout      = 3
  s3_bucket             = "ksz-demo-${local.function_name}"
  s3_key                = "lambda-${local.function_name}.zip"
}

terraform {
  required_version = "~> 0.12"
  required_providers {
    aws  = "~> 2.33"
    null = "~> 2.1"
  }
}

provider "aws" {
  region                  = local.aws_region
  shared_credentials_file = "$HOME/.aws/credentials"
  profile                 = local.aws_profile
}

# get account id
data "aws_caller_identity" "default" {}

# get region name
data "aws_region" "default" {
  name = local.aws_region
}

# get properties of package on s3
# for obvious reasons package must be created beforehand
data "aws_s3_bucket_object" "package" {
  bucket = local.s3_bucket
  key    = local.s3_key

  depends_on = [null_resource.package]
}

# set content of assume role policy for lambda
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

# set content of policy that will be attached to lambda role
data "aws_iam_policy_document" "demo" {
  policy_id = "lambda-function-policy"

  # allow writing logs in cloudwatch
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
      "arn:aws:logs:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:log-group:/aws/lambda/${local.function_name}:*"
    ]
  }
}

# creates deployment package for lambda
# will be triggered anytime files in lambda-source directory change
# for obious reasons bucket exists beforehand
resource "null_resource" "package" {
  triggers = {
    files_hash = base64sha256(join("", [for source_file in fileset("../${local.function_dir}", "*") : filesha256("../${local.function_dir}/${source_file}")]))
  }

  provisioner "local-exec" {
    command     = "./lambda.sh deploy ${local.function_name} ${local.function_runtime} ${local.aws_profile} ${local.s3_bucket} ${local.s3_key}"
    working_dir = "../${local.function_dir}"
  }
  depends_on = [aws_s3_bucket.demo]
}

# bucket where package will be placed
resource "aws_s3_bucket" "demo" {
  acl    = "private"
  bucket = local.s3_bucket
}

# role used by lambda
resource "aws_iam_role" "demo" {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = "Role for ${local.function_name} Lambda"
  name               = "${local.function_name}-role"
}

# attach policy to the role
resource "aws_iam_role_policy" "demo" {
  name   = "${local.function_name}-policy"
  policy = data.aws_iam_policy_document.demo.json
  role   = aws_iam_role.demo.id
}

# main function
# update will be trigger only when filebase64sha256 tag on package object changes
# for obvious reasons role and package must exist beforehand
resource "aws_lambda_function" "demo" {
  description      = "Lambda example demo"
  function_name    = local.function_name
  handler          = "index.handler"
  memory_size      = local.function_memory_limit
  role             = aws_iam_role.demo.arn
  runtime          = local.function_runtime
  s3_bucket        = aws_s3_bucket.demo.id
  s3_key           = local.s3_key
  source_code_hash = data.aws_s3_bucket_object.package.tags.filebase64sha256
  timeout          = local.function_timeout

  environment {
    variables = {
      SOME_VAR = local.env_some_var
    }
  }

  depends_on = [
    aws_iam_role.demo,
    null_resource.package,
  ]
}
