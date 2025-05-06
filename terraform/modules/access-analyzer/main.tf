variable "analyzer_name" {
  description = "Name of the AWS Access Analyzer"
  type        = string
  default     = "org-analyzer"

}

variable "tags" {
  description = "Common tags to add to all resources in this module"
  type        = map(string)
}

resource "aws_accessanalyzer_analyzer" "org" {
  analyzer_name = var.analyzer_name
  type          = "ORGANIZATION" # covers every AWS account in the Organization
  tags          = var.tags
}

output "analyzer_arn" {
  value = aws_accessanalyzer_analyzer.org.arn
}

