terraform {
  backend "s3" {}
  required_version = "~> 0.12"
}

provider "aws" {
  region  = local.aws_default_region
  version = "~> 2.27"

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/${var.automation_role_name}"
  }
}

# LOCAL VARIABLES
locals {
  common_tags = {
    environment = var.environment
    product     = var.product
    repository  = var.repository
    team        = var.team
  }
  account_long                     = var.account_long
  account_short                    = var.account_short
  alarms_forward_lambda            = var.alarms_forward_lambda
  alarms_forward_lambda_name       = "${local.product_short}-${local.alarms_forward_lambda}"
  alarms_forward_log_group         = "/aws/lambda/${local.alarms_forward_lambda_name}"
  aws_default_region               = var.aws_default_region
  bucket_stack_metadata_name       = "${var.bucket_stack_metadata_prefix}-${var.account_short}-${var.environment}-${var.aws_default_region_short}"
  docker_dir                       = var.docker_dir
  environment                      = var.environment
  log_retention                    = var.log_retention != 0 ? var.log_retention : var.retention_medium # log_retention uses retention_medium value as default
module_name                      = "notifications"
notifications_enabled            = var.notifications_enabled
notifications_incident_email     = var.notifications_incident_email
notifications_incident_phone     = var.notifications_incident_phone
notifications_infra_email        = var.notifications_infra_email
notifications_warning_email      = var.notifications_warning_email
policy_path                      = "/${var.product_short}/${var.environment}/${local.module_name}/"
prod_account                     = var.account_short == "prod" # prod_account for conditional resources only for prod account
product_short                    = var.product_short
repository                       = var.repository
resource_prefix                  = "${var.product_short}-${var.environment}-${local.module_name}"
static_environment               = var.environment == "static" # static_environment precaution to run this module only in static environment
team                             = var.team
tg_dir                           = var.tg_dir
topic_alarms_forward             = "${local.resource_prefix}-alarms-forward"
topic_incident                   = "${local.resource_prefix}-incident"
topic_infra                      = "${local.resource_prefix}-infrastructure"
topic_warning                    = "${local.resource_prefix}-warning"
victorops_cloudwatch_api_key     = var.victorops_cloudwatch_api_key
victorops_cloudwatch_endpoint    = "https://alert.victorops.com/integrations/cloudwatch/20131130/alert/${var.victorops_cloudwatch_api_key}/${var.victorops_cloudwatch_routing_key}"
victorops_cloudwatch_routing_key = var.victorops_cloudwatch_routing_key
victorops_enabled                = var.victorops_enabled
}

# DATA SOURCES - GET
# get identity used; for acquiring account number
data "aws_caller_identity" "default" {}

# get default region name
data "aws_region" "default" {
name = local.aws_default_region
}

# to read information exported by static/packages module
data "terraform_remote_state" "packages" {
backend = "s3"

config = {
bucket = local.bucket_stack_metadata_name
region = data.aws_region.default.name
key    = "terragrunt/${local.repository}/${local.account_long}/static/packages/terraform.tfstate"
}
}

# read properties of lambda packages to find hash in tags
data "aws_s3_bucket_object" "alarms_forward_package" {
bucket = local.bucket_stack_metadata_name
key    = data.terraform_remote_state.packages.outputs.alarms_forward_key
}

# DATA SOURCES - SET
# set policy allowing different services publishing to sns topics
data "aws_iam_policy_document" "incident_topic" {
policy_id = "incident-topic"

statement {
sid     = "CloudWatchPublish"
actions = ["sns:Publish"]

principals {
identifiers = ["*"]
type        = "AWS"
}

condition {
test     = "ArnEquals"
values   = ["arn:aws:cloudwatch:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:alarm:*"]
variable = "aws:SourceArn"
}

resources = ["arn:aws:sns:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:${local.topic_incident}"]
}
}

data "aws_iam_policy_document" "infra_topic" {
policy_id = "infra-topic"

statement {
sid     = "CloudWatchPublish"
actions = ["sns:Publish"]

principals {
identifiers = ["*"]
type        = "AWS"
}

condition {
test     = "ArnEquals"
values   = ["arn:aws:cloudwatch:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:alarm:*"]
variable = "aws:SourceArn"
}

resources = ["arn:aws:sns:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:${local.topic_infra}"]
}

statement {
sid     = "BudgetsPublish"
actions = ["sns:Publish"]

principals {
identifiers = ["budgets.amazonaws.com"]
type        = "Service"
}

resources = ["arn:aws:sns:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:${local.topic_infra}"]
}
}

data "aws_iam_policy_document" "warning_topic" {
policy_id = "warning-topic"

statement {
sid     = "Alarms"
actions = ["sns:Publish"]

principals {
identifiers = ["*"]
type        = "AWS"
}

condition {
test     = "ArnEquals"
values   = ["arn:aws:cloudwatch:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:alarm:*"]
variable = "aws:SourceArn"
}

resources = ["arn:aws:sns:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:${local.topic_warning}"]
}

statement {
sid     = "Budgets"
actions = ["sns:Publish"]

principals {
identifiers = ["budgets.amazonaws.com"]
type        = "Service"
}

resources = ["arn:aws:sns:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:${local.topic_warning}"]
}
}

# set assume role policy used by lambdas
data "aws_iam_policy_document" "lambda_assume_role" {
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

# set policy for alarms-forward lambda, allowing to publish in sns, create logs, read other lambdas and from cloudwatch
data "aws_iam_policy_document" "alarms_forward" {
policy_id = "alarms-forward"

statement {
sid     = "TopicsPublish"
actions = ["sns:Publish"]
effect  = "Allow"
resources = [
"arn:aws:sns:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:${local.topic_infra}",
"arn:aws:sns:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:${local.topic_alarms_forward}",
]
}

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
"arn:aws:logs:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:log-group:${local.alarms_forward_log_group}:*"
]
}

statement {
sid     = "LambdaRead"
actions = ["lambda:GetFunction"]
effect  = "Allow"
resources = [
"arn:aws:lambda:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:function:*"
]
}

statement {
sid     = "CloudWatchRead"
actions = ["cloudwatch:DescribeAlarmHistory"]
effect  = "Allow"
resources = [
"arn:aws:cloudwatch:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:alarm:*"
]
}
}

# RESOURCES - SNS topic: incident
# topic for reporting incidents with applications
resource "aws_sns_topic" "incident" {
count = local.static_environment ? 1 : 0

display_name = title("${local.team} - ${local.module_name} - incident - ${local.account_short}")
name         = "${local.resource_prefix}-incident"

//  lifecycle {
//    prevent_destroy = true
//  }

tags = merge({ terraform_resource = "aws_sns_topic.incident" }, { terraform_count = "0" }, local.common_tags)
}

# incident topic email subscription
# CAUTION: following is not supported by terraform yet, therefore will be replace with small CloudFormation stack
//resource "aws_sns_topic_subscription" "incident_email" {
//  count = local.static_environment && local.notifications_incident_enabled && local.notifications_incident_email != "" ? 1 : 0
//
//  endpoint  = local.notifications_incident_email
//  protocol  = "email"
//  topic_arn = aws_sns_topic.incident[0].arn
//}
resource "aws_cloudformation_stack" "subscription_incident_email" {
count = local.static_environment && local.notifications_enabled && local.notifications_incident_email != "" ? 1 : 0

name          = "${local.resource_prefix}-subscription-incident-email"
template_body = file("${local.tg_dir}/templates/cloudformation/aws_sns_topic_subscription.email.yaml")
parameters = {
EmailAddress = local.notifications_incident_email
TopicArn     = aws_sns_topic.incident[0].arn
}

depends_on = [aws_sns_topic.incident]

tags = merge({ terraform_resource = "aws_cloudformation_stack.subscription_incident_email" }, { terraform_count = "0" }, local.common_tags)
}


# incident topic sms subscription
resource "aws_sns_topic_subscription" "incident_sms" {
count = local.static_environment && local.notifications_enabled && local.notifications_incident_phone != "" ? 1 : 0

endpoint  = local.notifications_incident_phone
protocol  = "sms"
topic_arn = aws_sns_topic.incident[0].arn
}

# RESOURCES - SNS topic: infra
# topic for reporting issues with infrastructure
resource "aws_sns_topic" "infra" {
count = local.static_environment ? 1 : 0

display_name = title("${local.team} - ${local.module_name} - infrastructure - ${local.account_short}")
name         = "${local.resource_prefix}-infra"

//  lifecycle {
//    prevent_destroy = true
//  }

tags = merge({ terraform_resource = "aws_sns_topic.infra" }, { terraform_count = "0" }, local.common_tags)
}

# infra topic policy
resource "aws_sns_topic_policy" "infra" {
count = local.static_environment ? 1 : 0

arn    = aws_sns_topic.infra[0].arn
policy = data.aws_iam_policy_document.infra_topic.json
}

# infra topic email subscription
# CAUTION: following is not supported by terraform yet, therefore will be replace with small CloudFormation stack
//resource "aws_sns_topic_subscription" "infra_email" {
//  count = local.static_environment && local.notifications_infra_enabled && local.notifications_infra_email != "" ? 1 : 0
//
//  endpoint  = local.notifications_infra_email
//  protocol  = "email"
//  topic_arn = aws_sns_topic.infra[0].arn
//}
resource "aws_cloudformation_stack" "subscription_infra_email" {
count = local.static_environment && local.notifications_enabled && local.notifications_infra_email != "" ? 1 : 0

name          = "${local.resource_prefix}-subscription-infra-email"
template_body = file("${local.tg_dir}/templates/cloudformation/aws_sns_topic_subscription.email.yaml")
parameters = {
EmailAddress = local.notifications_infra_email
TopicArn     = aws_sns_topic.infra[0].arn
}

depends_on = [aws_sns_topic.infra]

tags = merge({ terraform_resource = "aws_cloudformation_stack.subscription_infra_email" }, { terraform_count = "0" }, local.common_tags)
}

# infra topic victorops subscription, conditional
resource "aws_sns_topic_subscription" "infra_victorops" {
count = local.static_environment && local.victorops_enabled && local.notifications_enabled && local.victorops_cloudwatch_api_key != "" && local.victorops_cloudwatch_routing_key != "" ? 1 : 0

endpoint  = local.victorops_cloudwatch_endpoint
protocol  = "https"
topic_arn = aws_sns_topic.infra[0].arn
}

# RESOURCES - SNS topic: warning
# topic for reporting warnings from applications
resource "aws_sns_topic" "warning" {
count = local.static_environment ? 1 : 0

display_name = title("${local.team} - ${local.module_name} - warning - ${local.account_short}")
name         = "${local.resource_prefix}-warning"

//  lifecycle {
//    prevent_destroy = true
//  }

tags = merge({ terraform_resource = "aws_sns_topic.warning" }, { terraform_count = "0" }, local.common_tags)
}

# warning topic policy
resource "aws_sns_topic_policy" "warning" {
count = local.static_environment && local.notifications_enabled ? 1 : 0

arn    = aws_sns_topic.warning[0].arn
policy = data.aws_iam_policy_document.warning_topic.json
}

# warning topic email subscription
# CAUTION: following is not supported by terraform yet, therefore will be replace with small CloudFormation stack
//resource "aws_sns_topic_subscription" "warning_email" {
//  count = local.static_environment && local.notifications_warning_enabled && local.notifications_warning_email != "" ? 1 : 0
//
//  endpoint  = local.notifications_warning_email
//  protocol  = "email"
//  topic_arn = aws_sns_topic.warning[0].arn
//}
resource "aws_cloudformation_stack" "subscription_warning_email" {
count = local.static_environment && local.notifications_enabled && local.notifications_warning_email != "" ? 1 : 0

name          = "${local.resource_prefix}-subscription-warning-email"
template_body = file("${local.tg_dir}/templates/cloudformation/aws_sns_topic_subscription.email.yaml")
parameters = {
EmailAddress = local.notifications_warning_email
TopicArn     = aws_sns_topic.warning[0].arn
}

depends_on = [aws_sns_topic.warning]

tags = merge({ terraform_resource = "aws_cloudformation_stack.subscription_warning_email" }, { terraform_count = "0" }, local.common_tags)
}

// RESOURCES - Lambda: forward-alarms
# log group for lambda
resource "aws_cloudwatch_log_group" "alarms_forward" {
count = local.static_environment ? 1 : 0

retention_in_days = local.log_retention
name              = local.alarms_forward_log_group
tags              = merge({ terraform_resource = "aws_cloudwatch_log_group.alarms_forward" }, { terraform_count = "0" }, local.common_tags)
}

# role used to allow send sns notifications, read all data and save logs
resource "aws_iam_role" "alarms_forward" {
count = local.static_environment ? 1 : 0

assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
description        = "Allows sending SNS notification via ${local.alarms_forward_lambda} Lambda."
name               = "${local.resource_prefix}-${local.alarms_forward_lambda}-role"
path               = local.policy_path

tags = merge({ terraform_resource = "aws_iam_role.alarms_forward" }, { terraform_count = "0" }, local.common_tags)
}

# policy used to allow send sns notifications, read all data and save logs
resource "aws_iam_policy" "alarms_forward" {
count = local.static_environment ? 1 : 0

name        = "${local.resource_prefix}-${local.alarms_forward_lambda}-policy"
description = "Allows sending SNS notification via ${local.alarms_forward_lambda} Lambda."
path        = local.policy_path
policy      = data.aws_iam_policy_document.alarms_forward.json
}

# role and policy for alarms-forward lambda
resource "aws_iam_role_policy_attachment" "alarms_forward" {
count = local.static_environment ? 1 : 0

policy_arn = aws_iam_policy.alarms_forward[0].arn
role       = aws_iam_role.alarms_forward[0].name
}

# alarms-forward lambda function
resource "aws_lambda_function" "alarms_forward" {
count = local.static_environment ? 1 : 0

function_name    = local.alarms_forward_lambda_name
description      = "Forwards CloudWatch alarms with additional information."
handler          = "index.handler"
memory_size      = 128
role             = aws_iam_role.alarms_forward[0].arn
runtime          = "python3.7"
s3_bucket        = local.bucket_stack_metadata_name
s3_key           = data.terraform_remote_state.packages.outputs.alarms_forward_key
source_code_hash = data.aws_s3_bucket_object.alarms_forward_package.tags.filebase64sha256
timeout          = 5

environment {
variables = {
NOTIFICATION_SNS_ARN = aws_sns_topic.infra[0].arn
LOG_LEVEL            = "INFO"
}
}

tags = merge({ terraform_resource = "aws_lambda_function.alarms_forward" }, { terraform_count = "0" }, local.common_tags)
}

# sns topic used by alarms-forward lambda
resource "aws_sns_topic" "alarms_forward" {
count = local.static_environment ? 1 : 0

name         = "${local.resource_prefix}-${local.alarms_forward_lambda}"
display_name = title("${local.team} - ${local.module_name} - alarms - ${local.account_short}")

tags = merge({ terraform_resource = "aws_sns_topic.alarms_forward" }, { terraform_count = "0" }, local.common_tags)
}

# topic for alarms-forward topic
//resource "aws_sns_topic_policy" "alarms_forward" {
//  count = local.static_environment ? 1 : 0
//
//  arn    = aws_sns_topic.alarms_forward[0].arn
//  policy = data.aws_iam_policy_document.alarms_forward.json
//}

# alarms-forward topic victorops subscription, conditional
# even when lambda fails victorops will be notified
resource "aws_sns_topic_subscription" "alarms_forward_victorops" {
count = local.victorops_enabled && local.static_environment && local.notifications_enabled && local.victorops_cloudwatch_api_key != "" && local.victorops_cloudwatch_routing_key != "" ? 1 : 0

endpoint  = local.victorops_cloudwatch_endpoint
protocol  = "https"
topic_arn = aws_sns_topic.alarms_forward[0].arn
}

# trigger alarms-forward lambda when cloudwatch alarm sends notification
resource "aws_sns_topic_subscription" "alarms_forward_lambda" {
count = local.static_environment && local.notifications_enabled ? 1 : 0

endpoint  = aws_lambda_function.alarms_forward[0].arn
protocol  = "lambda"
topic_arn = aws_sns_topic.alarms_forward[0].arn
}

# allow alarms-forward lambda be triggered by sns
resource "aws_lambda_permission" "alarms_forward" {
count = local.static_environment ? 1 : 0

action        = "lambda:InvokeFunction"
function_name = aws_lambda_function.alarms_forward[0].function_name
principal     = "sns.amazonaws.com"
source_arn    = aws_sns_topic.alarms_forward[0].arn
}

resource "aws_cloudwatch_metric_alarm" "alarms_forward" {
count = local.static_environment && local.notifications_enabled ? 1 : 0

alarm_name          = "${local.resource_prefix}-${local.alarms_forward_lambda}"
alarm_description   = "Triggers when ${local.alarms_forward_lambda} Lambda fails."
alarm_actions       = [aws_sns_topic.infra[0].arn]
comparison_operator = "GreaterThanThreshold"
evaluation_periods  = 1
metric_name         = "Errors"
namespace           = "AWS/Lambda"
ok_actions          = [aws_sns_topic.infra[0].arn]
period              = 60
statistic           = "Sum"
threshold           = 0
treat_missing_data  = "notBreaching"

dimensions = {
FunctionName = local.alarms_forward_lambda
}

tags = merge({ terraform_resource = "aws_cloudwatch_metric_alarm.alarms_forward" }, { terraform_count = "0" }, local.common_tags)
}