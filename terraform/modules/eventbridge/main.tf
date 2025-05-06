############################
# VARIABLES
############################

variable "lambda_arn" {
  type        = string
  description = "ARN of the Lambda function to forward findings to Splunk"
}

variable "analyzer_arn" {
  type        = string
  description = "ARN of the AWS Access Analyzer"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key for encryption"
}

variable "tags" {
  type        = map(string)
  description = "Common tags to add to all resources in this module"
}

############################
# CLOUDWATCH LOG GROUP RESOURCES
############################


resource "aws_cloudwatch_log_group" "rule_logs" {
  name              = "/aws/events/org-access-analyzer"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn
}

# Gives EventBridge permission to write to the log group
resource "aws_cloudwatch_log_resource_policy" "allow_events" {
  policy_name = "AllowEventBridgeToCWLogs"
  policy_document = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "events.amazonaws.com"
      },
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Resource = "arn:aws:logs:*:*:log-group:/aws/events/*"
    }]
  })
}

############################
# EVENTBRIDGE RESOURCES
############################

resource "aws_cloudwatch_event_rule" "access_analyzer_findings" {
  name        = "OrgAccessAnalyzerToSplunk"
  description = "Forwards IAM Access Analyzer findings to Splunk Lambda"

  event_pattern = jsonencode({
    "source" : ["aws.access-analyzer"]
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule = aws_cloudwatch_event_rule.access_analyzer_findings.name
  arn  = var.lambda_arn

  retry_policy { maximum_event_age_in_seconds = 900 }
}
