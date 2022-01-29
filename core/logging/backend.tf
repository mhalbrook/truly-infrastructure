terraform {
  backend "s3" {
    bucket         = "us-east-1-halbromr-terraform-state-backend"
    region         = "us-east-1"
    profile        = "default"
    key            = "core/logging/terraform.tfstate"
    dynamodb_table = "terraform-leveraged-state-lock"
  }
}