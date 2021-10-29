data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"
  source_dir  = "${path.module}/functions/"
}

## Share Lambda function:
##  will share each new EBS snapshot with the target account

resource "aws_lambda_function" "share" {
  provider         = aws.source
  function_name    = "ebs-snapshots-replicator-share-${var.name}"
  role             = aws_iam_role.share_lambda.arn
  handler          = "lambda.share_ebs_snapshot"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"
  architectures    = ["arm64"]
  timeout          = "120"

  environment {
    variables = local.lambda_default_environment_variables
  }

  lifecycle {
    ignore_changes = [
      filename
    ]
  }
}

resource "aws_cloudwatch_event_rule" "invoke_share_lambda" {
  provider      = aws.source
  description   = "Triggers lambda function ${aws_lambda_function.share.function_name}"
  event_pattern = <<EOF
{
  "source": ["aws.ec2"],
  "detail-type": ["EBS Snapshot Notification"],
  "detail": {
    "event": ["createSnapshot"],
    "result": ["succeeded"]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "invoke_share_lambda" {
  provider = aws.source
  rule     = aws_cloudwatch_event_rule.invoke_share_lambda.name
  arn      = aws_lambda_function.share.arn
}

resource "aws_lambda_permission" "invoke_share_lambda" {
  provider      = aws.source
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.share.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.invoke_share_lambda.arn
}

## Copy Lambda function:
##  Copies a shared EBS snapshot in the target account

resource "aws_lambda_function" "copy" {
  provider         = aws.target
  function_name    = "ebs-snapshots-replicator-copy-${var.name}"
  role             = aws_iam_role.copy_lambda.arn
  handler          = "lambda.copy_ebs_snapshot"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"
  architectures    = ["arm64"]
  timeout          = "120"

  environment {
    variables = local.lambda_default_environment_variables
  }

  lifecycle {
    ignore_changes = [
      filename
    ]
  }
}

resource "aws_cloudwatch_event_rule" "invoke_copy_lambda" {
  provider      = aws.target
  description   = "Triggers lambda function ${aws_lambda_function.copy.function_name}"
  event_pattern = <<EOF
{
  "source": ["aws.ec2"],
  "detail-type": ["EBS Snapshot Notification"],
  "detail": {
    "event": ["shareSnapshot"],
    "result": ["succeeded"],
    "source": ["${data.aws_caller_identity.source.account_id}"]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "invoke_copy_lambda" {
  provider = aws.target
  rule     = aws_cloudwatch_event_rule.invoke_copy_lambda.name
  arn      = aws_lambda_function.copy.arn
}

resource "aws_lambda_permission" "invoke_copy_lambda" {
  provider      = aws.target
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.copy.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.invoke_copy_lambda.arn
}

## Cleanup Lambda function:
##  Runs periodically to delete old snapshots from the replica account,
##  based on the configured retention period.

resource "aws_lambda_function" "cleanup" {
  provider         = aws.target
  function_name    = "ebs-snapshots-replicator-cleanup-${var.name}"
  role             = aws_iam_role.cleanup_lambda.arn
  handler          = "lambda.cleanup_ebs_snapshots"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.9"
  architectures    = ["arm64"]
  timeout          = "120"

  environment {
    variables = local.lambda_default_environment_variables
  }

  lifecycle {
    ignore_changes = [
      filename
    ]
  }
}

resource "aws_cloudwatch_event_rule" "invoke_cleanup_lambda" {
  provider            = aws.target
  description         = "Triggers lambda function ${aws_lambda_function.cleanup.function_name}"
  schedule_expression = "cron(0 3 * * ? *)"
  is_enabled          = false
}

resource "aws_cloudwatch_event_target" "invoke_cleanup_lambda" {
  provider = aws.target
  rule     = aws_cloudwatch_event_rule.invoke_cleanup_lambda.name
  arn      = aws_lambda_function.cleanup.arn
}

resource "aws_lambda_permission" "invoke_cleanup_lambda" {
  provider      = aws.target
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cleanup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.invoke_cleanup_lambda.arn
}
