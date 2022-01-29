################################################################################
# Truly Certificate
################################################################################
module "truly" {
  source      = "./modules/certificate"
  environment = terraform.workspace
  domain_name = var.domain_truly

  providers = {
    aws.account    = aws
    aws.networking = aws
  }
}