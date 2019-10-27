remote_state {
  backend = "s3"

  config = {
    encrypt          = true
    bucket           = "${get_env("TF_VAR_bucket_stack_metadata_prefix", "mg-stack-dataprovisioning-model-metadata")}-${get_env("TF_VAR_account_short", "nonprod")}-static-${get_env("TF_VAR_aws_default_region_short", "euw1")}"
key              = "terragrunt/${get_env("TF_VAR_repository", "dataprovisioning-model-infra")}/${path_relative_to_include()}/terraform.tfstate"
region           = "${get_env("TF_VAR_aws_default_region", "eu-west-1")}"
dynamodb_table   = "${get_env("TF_VAR_repository", "dataprovisioning-model-infra")}-terraform-locks"
force_path_style = true
}
}

skip = true

terraform_version_constraint = ">= 0.12"
