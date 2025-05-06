variable "region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "splunk_hec_endpoint" {
  type        = string
  description = "Splunk HEC endpoint URL"
  default     = "https://splunk.example.com:8088/services/collector"

  validation {
    condition     = can(regex("https://[a-zA-Z0-9.-]+:[0-9]+/services/collector", var.splunk_hec_endpoint))
    error_message = "The Splunk HEC endpoint must be in the format https://<hostname>:<port>/services/collector"
  }
}

# Only use either the secret ARN or the SSM path, not both
variable "splunk_hec_token" {
  type        = string
  description = "Splunk HEC token Secret ARN"
  default     = ""
}

variable "hec_token_arn" {
  type        = string
  description = "Splunk HEC token Secret ARN"
  default     = "arn:aws:secretsmanager:us-east-1:194722401531:secret:splunk/hec/token-7TpRyb"
  # default     = ""
}

variable "hec_token_ssm_path" {
  type        = string
  description = "Splunk HEC token SSM path"
  default     = ""
  # default     = "/splunk/hec/token"
}

variable "notification_email" {
  type        = string
  description = "DLQ alert address"
  default     = "davidccunliffe@gmail.com"
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "The notification email must be a valid email address"
  }
}

variable "splunk_dry_run" {
  description = "When true, Lambda sends events to logs instead of Splunk"
  type        = bool
  default     = true
}


variable "tags" {
  description = "Common tags to add to all resources in this module"
  type        = map(string)
  default = {
    "Environment" = "production"
    "Project"     = "access-analyzer"
    "Owner"       = "davidccunliffe@gmail.com"
    "ManagedBy"   = "Terraform"
    "Terraform"   = "true"
  }
}
