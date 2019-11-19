
# USAGE:
# 1.  Initialize and see what will be created.
#         terraform init
#         terraform plan
# 2.  Apply changes and confirm by typing "yes".
#     Leave parallelism parameter as it's crutial to asure proper order of reating resources.
#         terraform apply -parallelism=1
# 3.  After playing with it and checking remove all created resources.
#         terraform destroy

# Try it yourself. It should be all within your free tier.

# instead of using variables use locals, just to simplify example
locals {
  aws_credentials_file  = "$HOME/.aws/credentials"
  aws_profile           = "demo"                               # name of profile from ~/.aws/credentials
  aws_region            = "eu-west-1"                          # name of AWS region to use
  env_some_var          = "Value for my variable"              # value for environment variable to set
  function_description  = "Lambda example demo"                # description of Lambda
  function_dir          = "lambda-source"                      # name of directory with Lambda source
  function_memory_limit = 128                                  # memory limit for Lambda
  function_name         = "example"                            # name of deployed Lambda
  function_runtime      = "python3.7"                          # runtime used by Lambda
  function_timeout      = 3                                    # timeout limit of Lambda
  s3_bucket_prefix      = "lambda-demo-${local.function_name}" # prefix of S3 bucket name  to put Lambda package
  s3_key                = "lambda-${local.function_name}.zip"  # key of Lambda package inside S3 bucket
}

# use local backend, store tfstate on disk, just to simply example
terraform {
  required_version = "~> 0.12"

  required_providers {
    aws  = "~> 2.33"
    null = "~> 2.1"
  }
}

# AWS provided details used
provider "aws" {
  profile                 = local.aws_profile
  region                  = local.aws_region
  shared_credentials_file = local.aws_credentials_file
}

# get account id from provided credentials
data "aws_caller_identity" "default" {}

# get default region name from provided credentials
data "aws_region" "default" {
  name = local.aws_region
}

# get properties of package on s3
# for obvious reasons package must be created beforehand
data "aws_s3_bucket_object" "package" {
  bucket = aws_s3_bucket.demo.bucket
  key    = local.s3_key

  depends_on = [
    aws_s3_bucket.demo,
    null_resource.package,
  ]
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

# define Log Group for Lambda, so it can be deleted when stack is destroy
resource "aws_cloudwatch_log_group" "demo" {
  name = "/aws/lambda/${local.function_name}"
}

# random string that will be added to S3 bucket name
resource "random_string" "demo" {
  length  = 10
  special = false
  upper   = false
}

# S3 bucket where package will be placed
# CAUTION: when stack is destroy this bucket and all its content will be deleted
resource "aws_s3_bucket" "demo" {
  acl           = "private"
  bucket        = "${local.s3_bucket_prefix}-${random_string.demo.result}"
  force_destroy = true # change this to false if you don't want to delete non-empty bucket
}

# creates deployment package for lambda
# will be triggered anytime files in function_dir directory change
# for obious reasons bucket exists beforehand
resource "null_resource" "package" {
  triggers = {
    files_hash = base64sha256(join("", [for source_file in fileset("../${local.function_dir}", "*") : filesha256("../${local.function_dir}/${source_file}")]))
  }

  provisioner "local-exec" {
    command     = "./lambda.sh deploy ${local.function_name} ${local.function_runtime} ${local.aws_profile} ${aws_s3_bucket.demo.bucket} ${local.s3_key}"
    working_dir = "../${local.function_dir}"
  }

  depends_on = [
    aws_s3_bucket.demo,
  ]
}



# IAM role used by lambda
resource "aws_iam_role" "demo" {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = "Role for ${local.function_name} Lambda"
  name               = "${local.function_name}-role"
}

# attach IAM policy to the IAM role used by Lambda
resource "aws_iam_role_policy" "demo" {
  name   = "${local.function_name}-policy"
  policy = data.aws_iam_policy_document.demo.json
  role   = aws_iam_role.demo.id
}

# main Lambda function definition
# update will be trigger only when filebase64sha256 tag on package object changes
# for obvious reasons role and package must exist beforehand
resource "aws_lambda_function" "demo" {
  description      = local.function_description
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
