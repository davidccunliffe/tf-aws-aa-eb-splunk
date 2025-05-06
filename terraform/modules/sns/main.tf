variable "notification_email" {
  type        = string
  description = "DLQ alert address"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key for encryption"
}

variable "tags" {
  type        = map(string)
  description = "Common tags to add to all resources in this module"
}

resource "aws_sns_topic" "alerts" {
  name              = "access-analyzer-dlq-alerts"
  kms_master_key_id = var.kms_key_arn
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

output "topic_arn" { value = aws_sns_topic.alerts.arn }

