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
  account_short                    = var.account_short
  account_long                     = var.account_long
  alarms_forward_key               = "lambdas/${var.product_short}/${var.environment}/${var.alarms_forward_lambda}.zip"
  alarms_forward_lambda            = var.alarms_forward_lambda
  aws_default_region               = var.aws_default_region
  bucket_stack_metadata_name       = "${var.bucket_stack_metadata_prefix}-${var.account_short}-${var.environment}-${var.aws_default_region_short}"
  docker_dir                       = var.docker_dir
  ec2_reboot_credit_balance_key    = "lambdas/${var.product_short}/${var.environment}/${var.ec2_reboot_credit_balance_lambda}.zip"
  ec2_reboot_credit_balance_lambda = var.ec2_reboot_credit_balance_lambda
  elasticsearch_curator_key        = "lambdas/${var.product_short}/${var.environment}/${var.elasticsearch_curator_lambda}.zip"
  elasticsearch_curator_lambda     = var.elasticsearch_curator_lambda
  elasticsearch_elastalert_key     = "lambdas/${var.product_short}/${var.environment}/${var.elasticsearch_elastalert_lambda}.zip"
  elasticsearch_elastalert_lambda  = var.elasticsearch_elastalert_lambda
  elasticsearch_endpoint_public    = "${local.elasticsearch_logging_domain}.${local.public_hosted_zone_name}"
  elasticsearch_logging_domain     = var.elasticsearch_logging_domain
  environment                      = var.environment
  module_name                      = "lambda"
  public_hosted_zone_name          = var.public_hosted_zone_name
  repository                       = var.repository
  resource_prefix                  = "${var.product_short}-${var.environment}-${local.module_name}"
  static_environment               = var.environment == "static" # static_environment precaution to run this module only in static environment
tg_dir                           = var.tg_dir
victorops_generic_api_key        = var.victorops_generic_api_key
victorops_generic_routing_key    = var.victorops_generic_routing_key
}

# DATA SOURCES - GET
# get default region name
data "aws_region" "default" {
name = local.aws_default_region
}


# to read storage information exported by static/notifications module
data "terraform_remote_state" "notifications" {
backend = "s3"

config = {
bucket = local.bucket_stack_metadata_name
region = data.aws_region.default.name
key    = "terragrunt/${local.repository}/${local.account_long}/static/notifications/terraform.tfstate"
}
}

# incidient notification topic
data "aws_sns_topic" "incident" {
name = data.terraform_remote_state.notifications.outputs.topic_incident_name
}

# infra notifications topic
data "aws_sns_topic" "infra" {
name = data.terraform_remote_state.notifications.outputs.topic_infra_name
}

# warning notification topic
data "aws_sns_topic" "warning" {
name = data.terraform_remote_state.notifications.outputs.topic_warning_name
}

# DATA SOURCES - SET
# used for outputs
data "null_data_source" "lambda_packages" {
inputs = {
alarms_forward_key            = local.alarms_forward_key
ec2_reboot_credit_balance_key = local.ec2_reboot_credit_balance_key
elasticsearch_curator_key     = local.elasticsearch_curator_key
elasticsearch_elastalert_key  = local.elasticsearch_elastalert_key
}
}

# RESOURCES
# creats deployment packages if important source files change
# need to be placed in separate module/stack to not race for update with aws_lambda_function

# RESOURCES: static/notifications
resource "null_resource" "alarms_forward_package" {
count = local.static_environment ? 1 : 0

triggers = {
files_hash = base64sha256(join("", [for source_file in fileset("${local.tg_dir}/lambdas/${local.alarms_forward_lambda}", "*") : filesha256("${local.tg_dir}/lambdas/${local.alarms_forward_lambda}/${source_file}")]))
}

provisioner "local-exec" {
command     = "./setup.sh ${local.alarms_forward_lambda} ${local.docker_dir} ${local.bucket_stack_metadata_name} ${local.alarms_forward_key}"
working_dir = "${local.tg_dir}/lambdas/${local.alarms_forward_lambda}"
}
}

# RESOURCES: static/monitoring
resource "null_resource" "ec2_reboot_credit_balance_package" {
count = local.static_environment ? 1 : 0

triggers = {
files_hash = base64sha256(join("", [for source_file in fileset("${local.tg_dir}/lambdas/${local.ec2_reboot_credit_balance_lambda}", "*") : filesha256("${local.tg_dir}/lambdas/${local.ec2_reboot_credit_balance_lambda}/${source_file}")]))
}

provisioner "local-exec" {
command     = "./setup.sh ${local.ec2_reboot_credit_balance_lambda} ${local.docker_dir} ${local.bucket_stack_metadata_name} ${local.ec2_reboot_credit_balance_key}"
working_dir = "${local.tg_dir}/lambdas/${local.ec2_reboot_credit_balance_lambda}"
}
}

resource "null_resource" "elasticsearch_curator_package" {
count = local.static_environment ? 1 : 0

triggers = {
files_hash = base64sha256(join("", [for source_file in fileset("${local.tg_dir}/lambdas/${local.elasticsearch_curator_lambda}", "*") : filesha256("${local.tg_dir}/lambdas/${local.elasticsearch_curator_lambda}/${source_file}")]))
}

provisioner "local-exec" {
command     = "./setup.sh ${local.elasticsearch_curator_lambda} ${local.docker_dir} ${local.bucket_stack_metadata_name} ${local.elasticsearch_curator_key}"
working_dir = "${local.tg_dir}/lambdas/${local.elasticsearch_curator_lambda}"
}
}

resource "null_resource" "elasticsearch_elastalert_package" {
count = local.static_environment ? 1 : 0

triggers = {
files_hash = base64sha256(join("", [for source_file in fileset("${local.tg_dir}/lambdas/${local.elasticsearch_elastalert_lambda}", "*") : filesha256("${local.tg_dir}/lambdas/${local.elasticsearch_elastalert_lambda}/${source_file}")]))
}

provisioner "local-exec" {
command     = "./setup.sh ${local.elasticsearch_elastalert_lambda} ${local.docker_dir} ${local.bucket_stack_metadata_name} ${local.elasticsearch_elastalert_key} ${local.aws_default_region} ${local.elasticsearch_endpoint_public} ${local.account_short} ${data.aws_sns_topic.incident.arn} ${data.aws_sns_topic.warning.arn} ${local.victorops_generic_api_key} ${local.victorops_generic_routing_key}"
working_dir = "${local.tg_dir}/lambdas/${local.elasticsearch_elastalert_lambda}"
}
}