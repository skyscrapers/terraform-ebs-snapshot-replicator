# EBS snapshot replicator Terraform module

This module sets up a mechanism to replicate EBS snapshots to a different AWS account and [region](#input_target_region). It does so by the means of several Lambda functions. It'll also regularly clean up old snapshots on the replicated AWS account based on a configurable [retention period](#input_retention_period).

This is how the module works to replicate EBS snapshots from a `source` AWS account to a `target` account:

1. There's a Lambda function running in the `source` AWS account that gets triggered on each EBS snapshot that's taken on the region. It is configured to look for a set of [tags](#input_match_tags), so all snapshots that do not contain those tags are ignored. Those snapshots that do match the configured tags are then shared to the `target` account.
2. There's a second Lambda function running in the `target` AWS account, it gets triggered on each EBS snapshot shared with that account. This function also filters by tags, so only the snapshots that match the set of tags are copied over to the `target` region within the account. This operation also re-encrypts the snapshot using a [KMS key in the `target` account](#input_target_account_kms_key_arn).
3. Another Lambda is triggered once per day to clean up snapshots in the `target` AWS account older than a configured [retention period](#input_retention_period).

Note that when working with encrypted EBS snapshots, the Lambda function running in the `target` account that performs the copy operation will need access to the KMS key used to encrypt the original snapshot in the `source` account. Setting the appropriate key policy on the used KMS keys falls out of the scope of this module, as the policy block needs to be defined within the `aws_kms_key` resource used to create the key. You can know more about how to share a KMS key with different AWS accounts [here](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-modifying-snapshot-permissions.html#share-kms-key).

Also note that this won't work for those snapshots encrypted with the default KMS key of the `source` AWS account, as those snapshots can't be shared with other accounts.

## Requirements

| Name                                                                      | Version   |
| ------------------------------------------------------------------------- | --------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0    |
| <a name="requirement_aws"></a> [aws](#requirement\_aws)                   | >= 3.61.0 |

## Providers

| Name                                                                   | Version   |
| ---------------------------------------------------------------------- | --------- |
| <a name="provider_archive"></a> [archive](#provider\_archive)          | n/a       |
| <a name="provider_aws.source"></a> [aws.source](#provider\_aws.source) | >= 3.61.0 |
| <a name="provider_aws.target"></a> [aws.target](#provider\_aws.target) | >= 3.61.0 |

## Modules

No modules.

## Resources

| Name                                                                                                                                                                   | Type        |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [aws_cloudwatch_event_rule.invoke_cleanup_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule)                   | resource    |
| [aws_cloudwatch_event_rule.invoke_copy_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule)                      | resource    |
| [aws_cloudwatch_event_rule.invoke_share_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule)                     | resource    |
| [aws_cloudwatch_event_target.invoke_cleanup_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target)               | resource    |
| [aws_cloudwatch_event_target.invoke_copy_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target)                  | resource    |
| [aws_cloudwatch_event_target.invoke_share_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target)                 | resource    |
| [aws_iam_role.cleanup_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                    | resource    |
| [aws_iam_role.copy_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                       | resource    |
| [aws_iam_role.share_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                                      | resource    |
| [aws_iam_role_policy.cleanup_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)                                      | resource    |
| [aws_iam_role_policy.copy_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)                                         | resource    |
| [aws_iam_role_policy.copy_lambda_assume_share_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)                       | resource    |
| [aws_iam_role_policy.share_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy)                                        | resource    |
| [aws_iam_role_policy_attachment.cleanup_lambda_exec_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)      | resource    |
| [aws_iam_role_policy_attachment.copy_lambda_exec_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)         | resource    |
| [aws_iam_role_policy_attachment.share_lambda_exec_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)        | resource    |
| [aws_lambda_function.cleanup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function)                                             | resource    |
| [aws_lambda_function.copy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function)                                                | resource    |
| [aws_lambda_function.share](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function)                                               | resource    |
| [aws_lambda_permission.invoke_cleanup_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission)                           | resource    |
| [aws_lambda_permission.invoke_copy_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission)                              | resource    |
| [aws_lambda_permission.invoke_share_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission)                             | resource    |
| [archive_file.lambda_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file)                                                     | data source |
| [aws_caller_identity.source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)                                           | data source |
| [aws_caller_identity.target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity)                                           | data source |
| [aws_iam_policy_document.assume_share_role_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)            | data source |
| [aws_iam_policy_document.cleanup_lambda_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)               | data source |
| [aws_iam_policy_document.copy_lambda_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                  | data source |
| [aws_iam_policy_document.lambda_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                | data source |
| [aws_iam_policy_document.share_lambda_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)                 | data source |
| [aws_iam_policy_document.target_account_lambda_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region)                                                             | data source |

## Inputs

| Name                                                                                                                     | Description                                                                                   | Type          | Default | Required |
| ------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------- | ------------- | ------- | :------: |
| <a name="input_match_tags"></a> [match\_tags](#input\_match\_tags)                                                       | AWS tags to match the EBS volumes to replicate, in the form of `{key = value, key2 = value2}` | `map(string)` | n/a     |   yes    |
| <a name="input_name"></a> [name](#input\_name)                                                                           | Name of the setup                                                                             | `string`      | n/a     |   yes    |
| <a name="input_retention_period"></a> [retention\_period](#input\_retention\_period)                                     | Snapshot retention period in days                                                             | `number`      | `14`    |    no    |
| <a name="input_target_account_kms_key_arn"></a> [target\_account\_kms\_key\_arn](#input\_target\_account\_kms\_key\_arn) | KMS key to use to encrypt replicated RDS snapshots in the target AWS account                  | `string`      | n/a     |   yes    |
| <a name="input_target_region"></a> [target\_region](#input\_target\_region)                                              | Target region where to copy the EBS snapshots                                                 | `string`      | n/a     |   yes    |

## Outputs

No outputs.

## Example

```hcl
variable "source_region" {
  default = "eu-west-1"
}

variable "target_region" {
  default = "eu-central-1"
}

provider "aws" {
  alias               = "production"
  region              = var.source_region
  profile             = "Production"
}

# Note that the replica provider is still configured with the source region as there's where the lambdas are deployed
provider "aws" {
  alias               = "replica"
  region              = var.source_region
  profile             = "Replica"
}

provider "aws" {
  alias               = "replica_target_region"
  region              = var.target_region
  profile             = "Replica"
}

resource "aws_kms_key" "ebs_replicator" {
  provider    = aws.replica_target_region
  description = "KMS key to encrypt replicated EBS snapshots"
}

module "ebs_replicator" {
  source                     = "github.com/skyscrapers/terraform-ebs-snapshot-replicator"
  name                       = "velero"
  target_account_kms_key_arn = aws_kms_key.ebs_replicator.arn
  target_region              = var.target_region
  retention_period           = 15

  match_tags = {
    "kubernetes.io/cluster/production-eks-foo" = "owned"
    "velero.io/schedule-name"                  = "velero-cluster-backup"
  }

  providers = {
    aws.source = aws.production
    aws.target = aws.replica
  }
}
```
