# get module
terraform {
  source = "${get_env("TF_VAR_tg_dir", get_terragrunt_dir())}/modules//packages"
}

# include settings from the root terragrunt.hcl file
include {
path = "${get_env("TF_VAR_tg_dir", get_terragrunt_dir())}/infra/terragrunt.hcl"
}

# variables passed to module
inputs = {
}