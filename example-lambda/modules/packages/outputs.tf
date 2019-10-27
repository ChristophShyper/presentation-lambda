output "alarms_forward_key" {
  value = data.null_data_source.lambda_packages.outputs.alarms_forward_key
}

output "ec2_reboot_credit_balance_key" {
  value = data.null_data_source.lambda_packages.outputs.ec2_reboot_credit_balance_key
}

output "elasticsearch_curator_key" {
  value = data.null_data_source.lambda_packages.outputs.elasticsearch_curator_key
}

output "elasticsearch_elastalert_key" {
  value = data.null_data_source.lambda_packages.outputs.elasticsearch_elastalert_key
}
