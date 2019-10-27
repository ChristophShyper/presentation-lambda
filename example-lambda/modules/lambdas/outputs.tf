output "topic_alarms_forward_arn" {
  description = "ARN of SNS topic for Lambda alarms with additional filtering by alarms-forward Lambda."
  value       = aws_sns_topic.alarms_forward[0].arn
}

output "topic_alarms_forward_name" {
description = "Name of SNS topic for Lambda alarms with additional filtering by alarms-forward Lambda."
value       = aws_sns_topic.alarms_forward[0].name
}

output "topic_incident_arn" {
description = "ARN of SNS topic for reporting application incidents."
value       = aws_sns_topic.incident[0].arn
}

output "topic_incident_name" {
description = "Name of SNS topic for reporting application incidents."
value       = aws_sns_topic.incident[0].name
}

output "topic_infra_arn" {
description = "ARN of SNS topic for reporting issues with infrastructure."
value       = aws_sns_topic.infra[0].arn
}

output "topic_infra_name" {
description = "Name of SNS topic for reporting issues with infrastructure."
value       = aws_sns_topic.infra[0].name
}

output "topic_warning_arn" {
description = "ARN of SNS topic for reporting application warnings."
value       = aws_sns_topic.warning[0].arn
}

output "topic_warning_name" {
description = "Name of SNS topic for reporting application warnings."
value       = aws_sns_topic.warning[0].name
}
