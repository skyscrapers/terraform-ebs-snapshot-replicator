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

locals {
  setup_name = "ebs-snapshot-replicator-${var.name}"

  lambda_default_environment_variables = {
    TARGET_ACCOUNT_ID          = data.aws_caller_identity.target.account_id
    SOURCE_REGION              = data.aws_region.source.name
    TARGET_REGION              = var.target_region
    MATCH_TAGS                 = jsonencode(var.match_tags)
    TARGET_ACCOUNT_KMS_KEY_ARN = var.target_account_kms_key_arn
    SETUP_NAME                 = local.setup_name
    RETENTION_PERIOD           = var.retention_period
    SOURCE_ACCOUNT_IAM_ROLE    = aws_iam_role.share_lambda.arn
  }
}
