data "aws_iam_policy_document" "lambda_assume_role_policy" {
  provider = aws.source

  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

## IAM resources on the source account

resource "aws_iam_role" "share_lambda" {
  provider           = aws.source
  name               = "ebs_snapshots_replicator_share_lambda_${var.name}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "share_lambda_permissions" {
  provider = aws.source

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:DescribeSnapshots",
      "ec2:DescribeSnapshotAttribute",
      "ec2:ModifySnapshotAttribute",
      # "kms:DescribeKey",
      # "kms:ReEncypt"
    ]
  }
}

resource "aws_iam_role_policy" "share_lambda" {
  provider = aws.source
  role     = aws_iam_role.share_lambda.name
  policy   = data.aws_iam_policy_document.share_lambda_permissions.json
}

resource "aws_iam_role_policy_attachment" "share_lambda_exec_role" {
  provider   = aws.source
  role       = aws_iam_role.share_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

## IAM resources on the target account

resource "aws_iam_role" "copy_lambda" {
  provider           = aws.target
  name               = "ebs_snapshots_replicator_copy_lambda_${var.name}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "copy_lambda_permissions" {
  provider = aws.target

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:DescribeSnapshots",
      "ec2:DescribeSnapshotAttribute",
      "ec2:CopySnapshot",
      "ec2:CreateTags"
    ]
  }
}

resource "aws_iam_role_policy" "copy_lambda" {
  provider = aws.target
  role     = aws_iam_role.copy_lambda.name
  policy   = data.aws_iam_policy_document.copy_lambda_permissions.json
}

resource "aws_iam_role_policy_attachment" "copy_lambda_exec_role" {
  provider   = aws.target
  role       = aws_iam_role.copy_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "cleanup_lambda" {
  provider           = aws.target
  name               = "ebs_snapshots_replicator_cleanup_lambda_${var.name}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "cleanup_lambda_permissions" {
  provider = aws.target

  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:DescribeSnapshots",
      "ec2:DescribeSnapshotAttribute",
      "ec2:DeleteSnapshot"
    ]
  }
}

resource "aws_iam_role_policy" "cleanup_lambda" {
  provider = aws.target
  role     = aws_iam_role.cleanup_lambda.name
  policy   = data.aws_iam_policy_document.cleanup_lambda_permissions.json
}

resource "aws_iam_role_policy_attachment" "cleanup_lambda_exec_role" {
  provider   = aws.target
  role       = aws_iam_role.cleanup_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
