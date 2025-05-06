variable "tags" {
  type = map(string)
}

variable "region" {
  type        = string
  description = "AWS region"
}

data "aws_caller_identity" "this" {}

resource "aws_kms_key" "this" {
  description             = "CMK for access-analyzer-to-splunk project"
  enable_key_rotation     = true
  deletion_window_in_days = 10
  # policy              = data.aws_iam_policy_document.kms.json
  tags = var.tags

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Id" : "default",
    "Statement" : [
      {
        "Sid" : "DefaultAllow",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.this.account_id}:root"
        },
        "Action" : "kms:*",
        "Resource" : "*"

      },
      {
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action = [
          "kms:*"
        ]
        Resource = "*"
      }
    ]
  })
}

data "aws_iam_policy_document" "kms" {
  # Give ALL accounts in the Organisation full use of the key,
  # but nobody outside the Org.
  statement {
    sid    = "AllowAccountControl"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:root"]
    }
    actions = [
      "kms:*"
    ]
    resources = ["*"]
  }

  # CloudWatch Logs
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:Describe*",
      "kms:ListGrants"
    ]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  # Lambda
  statement {
    sid    = "AllowLambda"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:Describe*",
      "kms:ListGrants"
    ]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  # SQS
  statement {
    sid    = "AllowSQS"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sqs.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:Describe*",
      "kms:ListGrants"
    ]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  # SNS
  statement {
    sid    = "AllowSNS"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:Describe*",
      "kms:ListGrants"
    ]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}


resource "aws_kms_alias" "alias" {
  name          = "alias/access-analyzer-to-splunk"
  target_key_id = aws_kms_key.this.id
}

output "kms_key_arn" {
  value = aws_kms_key.this.arn
}
