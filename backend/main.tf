#############################################################
# Account IAM Alias
#############################################################
resource "aws_iam_account_alias" "alias" {
  provider      = aws
  account_alias = var.account_alias
}


##########################################################
#  Terraform Backend KMS Key
##########################################################
module "backend_kms" {
  source      = "./modules/kms"
  environment = terraform.workspace
  service     = "terraform-backend"
  suffix      = "terraform-backend"

  providers = {
    aws.account   = aws
    aws.secondary = aws
  }
}


##########################################################
#  S3 Access Terraform Backend
##########################################################
module "backend_s3" {
  source              = "./modules/s3"
  environment         = terraform.workspace
  bucket_name         = "terraform-state-backend"
  kms_key_arn         = module.backend_kms.key_arn[data.aws_region.region.name]
  data_classification = "internal"

  providers = {
    aws.account     = aws
    aws.replication = aws
  }
}


##########################################################
#  Terraform State Lock DynamoDB Table
##########################################################
module "terraform_state_lock" {
  source              = "git::ssh://git@bitbucket.org/v-dso/dynamodb?ref=v2.0"
  project             = "terraform"
  environment         = terraform.workspace
  table_name          = "state-lock"
  hash_key            = { "LockID" = "S" }
  kms_key_arn         = module.backend_kms.key_arn[data.aws_region.region.name]
  data_classification = "internal"

  providers = {
    aws.account = aws
  }
}