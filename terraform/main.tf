locals {
  project = "access-analyzer-to-splunk"
}

provider "aws" {
  region  = var.region
  profile = "security"
}

module "kms" {
  source = "./modules/kms"
  region = var.region
  tags   = var.tags
}

module "sns" {
  source             = "./modules/sns"
  notification_email = var.notification_email
  kms_key_arn        = module.kms.kms_key_arn
  tags               = var.tags
}

module "sqs" {
  source        = "./modules/sqs"
  kms_key_arn   = module.kms.kms_key_arn
  sns_topic_arn = module.sns.topic_arn
  tags          = var.tags
}

module "access_analyzer" {
  source = "./modules/access-analyzer"
  tags   = var.tags
}

module "splunk_lambda" {
  source = "./modules/splunk-lambda"
  region = var.region

  sqs_queue_arn = module.sqs.queue_arn
  dlq_arn       = module.sqs.dlq_arn

  hec_endpoint         = var.splunk_hec_endpoint
  hec_token            = var.splunk_hec_token
  hec_token_ssm_path   = var.hec_token_ssm_path
  hec_token_secret_arn = var.hec_token_arn
  kms_key_arn          = module.kms.kms_key_arn

  environment_overrides = {
    HEC_TEST_MODE = var.splunk_dry_run ? "true" : ""
  }

  tags = var.tags
}

module "replay_lambda" {
  source = "./modules/splunk-lambda"
  region = var.region

  function_suffix  = "-replay"
  event_source_arn = module.sqs.dlq_arn
  sqs_queue_arn    = ""
  dlq_arn          = ""

  hec_endpoint       = var.splunk_hec_endpoint
  hec_token          = var.splunk_hec_token
  hec_token_ssm_path = var.hec_token_ssm_path
  kms_key_arn        = module.kms.kms_key_arn

  environment_overrides = {
    HEC_TEST_MODE = var.splunk_dry_run ? "true" : ""
  }

  tags = var.tags
}

module "eventbridge" {
  source       = "./modules/eventbridge"
  lambda_arn   = module.splunk_lambda.lambda_arn
  analyzer_arn = module.access_analyzer.analyzer_arn
  kms_key_arn  = module.kms.kms_key_arn
  tags         = var.tags
}

