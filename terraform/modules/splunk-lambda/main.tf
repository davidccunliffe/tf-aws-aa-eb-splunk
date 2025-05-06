############################
# LOCAL VARIABLES
############################

locals {
  lambda_env = merge(
    {
      SPLUNK_HEC_ENDPOINT  = var.hec_endpoint
      SPLUNK_HEC_TOKEN     = var.hec_token != "" ? var.hec_token : ""
      HEC_TOKEN_SECRET_ARN = var.hec_token_secret_arn
      HEC_TOKEN_SSM_PATH   = var.hec_token_ssm_path
    },
    var.environment_overrides # empty map by default
  )
}

############################
# VARIABLES
############################

variable "hec_endpoint" {
  type        = string
  description = "Splunk HEC endpoint URL"
}

variable "hec_token" {
  type        = string
  sensitive   = true
  description = "Splunk HEC token"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for encrypting environment variables"
}

variable "sqs_queue_arn" {
  type        = string
  description = "SQS queue ARN for Lambda function"
  default     = ""
}

variable "dlq_arn" {
  type        = string
  description = "DLQ ARN for Lambda function"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Common tags to add to all resources in this module"
}

variable "region" {
  type        = string
  description = "AWS region to deploy resources in"
}

variable "function_suffix" {
  type        = string
  description = "Optional suffix to make multiple copies of the module coexist"
  default     = ""
}

variable "event_source_arn" {
  type        = string
  description = "If set, creates an SQS event-source mapping for this Lambda"
  default     = ""
}

variable "hec_token_secret_arn" {
  description = "ARN of Secrets Manager secret that stores the HEC token"
  type        = string
  default     = ""
}

variable "hec_token_ssm_path" {
  description = "Name or full path of SSM parameter that stores the HEC token"
  type        = string
  default     = ""
}

variable "environment_overrides" {
  description = "Optional extra environment variables to set on the Lambda"
  type        = map(string)
  default     = {}
}

############################
# LAMDA EXECUTION ROLE
############################
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"] # ⬅️  only Lambda
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "access-analyzer-splunk-lambda-role${var.function_suffix}"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "basic_logs" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "dlq_and_kms" {
  dynamic "statement" {
    for_each = var.sqs_queue_arn != "" ? [var.sqs_queue_arn] : []
    content {
      sid       = "SendToPrimaryQueue"
      effect    = "Allow"
      actions   = ["sqs:SendMessage"]
      resources = [statement.value]
    }
  }

  dynamic "statement" {
    for_each = var.dlq_arn != "" ? [var.dlq_arn] : []
    content {
      sid       = "SendToDLQ"
      effect    = "Allow"
      actions   = ["sqs:SendMessage"]
      resources = [statement.value]
    }
  }

  dynamic "statement" {
    for_each = var.event_source_arn != "" ? [var.event_source_arn] : []
    content {
      sid    = "ConsumeFromQueue"
      effect = "Allow"
      actions = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:ChangeMessageVisibility",
        "sqs:GetQueueAttributes"
      ]
      resources = [statement.value]
    }
  }

  dynamic "statement" {
    for_each = var.hec_token_secret_arn != "" ? [var.hec_token_secret_arn] : []
    content {
      sid       = "ReadHECTokenSecret"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [statement.value]
    }
  }

  dynamic "statement" {
    for_each = var.hec_token_ssm_path != "" ? [var.hec_token_ssm_path] : []
    content {
      sid       = "ReadHECTokenParameter"
      effect    = "Allow"
      actions   = ["ssm:GetParameter", "ssm:GetParameters"]
      resources = [statement.value]
    }
  }

  statement {
    sid    = "DecryptWithCMK"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "dlq_and_kms" {
  name   = "AllowDLQSendAndKMSDecrypt"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.dlq_and_kms.json
}

############################
# LAMBDA FUNCTION
############################
resource "aws_lambda_function" "this" {
  function_name = "access-analyzer-splunk-forwarder${var.function_suffix}"
  role          = aws_iam_role.this.arn
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"

  filename         = "${path.module}/src/build.zip"
  source_code_hash = filebase64sha256("${path.module}/src/build.zip")

  timeout     = 30
  memory_size = 512

  environment {
    variables = local.lambda_env
  }

  # Encrypt environment variables with your CMK
  kms_key_arn = var.kms_key_arn

  dynamic "dead_letter_config" {
    for_each = var.sqs_queue_arn != "" ? [var.sqs_queue_arn] : []
    content {
      target_arn = dead_letter_config.value
    }
  }

  tags = var.tags
}

############################
# EVENTBRIDGE INOKE PERMISSION
############################
resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  count = var.event_source_arn == "" ? 0 : 1

  event_source_arn                   = var.event_source_arn
  function_name                      = aws_lambda_function.this.arn
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  enabled                            = true
}


############################
# OUTPUTS
############################

output "lambda_arn" {
  value = aws_lambda_function.this.arn
}

output "lambda_name" {
  value = aws_lambda_function.this.function_name
}
