variable "account_alias" {
  description = "The IAM Account alias for the AWS Account in which resources are provisioned"
  type        = string
  default     = "halbromr"
}

variable "bucket_name" {
  description = "Friendly name for the S3 Bucket where Terraform Backend State Files are stored"
  type        = string
  default     = "halbromr"
}