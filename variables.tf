variable "name" {
  description = "Name of the setup"
  type        = string
}

variable "target_account_kms_key_id" {
  description = "KMS key to use to encrypt replicated RDS snapshots in the target AWS account"
  type        = string
}

variable "match_tags" {
  description = "AWS tags to match the EBS volumes to replicate, in the form of `{key = value, key2 = value2}`"
  type        = map(string)
}

variable "retention_period" {
  description = "Snapshot retention period in days"
  type        = number
  default     = 14
}

variable "target_region" {
  description = "Target region where to copy the EBS snapshots"
  type        = string
}
