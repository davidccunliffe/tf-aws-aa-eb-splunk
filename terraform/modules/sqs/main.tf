############################
# VARIABLES
############################
variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key for encryption"
}

variable "sns_topic_arn" {
  type        = string
  description = "ARN of the SNS topic for DLQ alerts"
}

variable "tags" {
  type        = map(string)
  description = "Common tags to add to all resources in this module"
}

############################
# SQS RESOURCES
############################

resource "aws_sqs_queue" "dlq" {
  name                      = "org-access-analyzer-splunk-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = var.kms_key_arn
}

resource "aws_sqs_queue" "primary" {
  name                      = "org-access-analyzer-splunk-queue"
  message_retention_seconds = 345600 # 4 days
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
  kms_master_key_id = var.kms_key_arn
}

# Notify when a message is sent to the DLQ
resource "aws_sns_topic_subscription" "dlq_alert" {
  topic_arn            = var.sns_topic_arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.dlq.arn
  raw_message_delivery = true
}

############################
# OUTPUTS
############################

output "queue_arn" {
  value = aws_sqs_queue.primary.arn
}
output "dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}
