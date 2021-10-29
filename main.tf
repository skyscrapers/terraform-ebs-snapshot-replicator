terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      version = ">= 3.61.0"
      configuration_aliases = [
        aws.source,
        aws.target
      ]
    }
  }
}

data "aws_caller_identity" "source" {
  provider = aws.source
}

data "aws_region" "source" {
  provider = aws.source
}

data "aws_caller_identity" "target" {
  provider = aws.target
}

data "aws_kms_key" "target_key" {
  provider = aws.target
  key_id   = var.target_account_kms_key_id
}

locals {
  setup_name = "ebs-snapshot-replicator-${var.name}"
  lambda_default_environment_variables = {
    TARGET_ACCOUNT_ID          = data.aws_caller_identity.target.account_id
    SOURCE_REGION              = data.aws_region.source.name
    TARGET_REGION              = var.target_region
    MATCH_TAGS                 = jsonencode(var.match_tags)
    TARGET_ACCOUNT_KMS_KEY_ARN = data.aws_kms_key.target_key.arn
    SETUP_NAME                 = local.setup_name
    RETENTION_PERIOD           = var.retention_period
  }
}
