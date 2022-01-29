################################################################################
# Hosted Zone inputs
################################################################################
data "aws_route53_zone" "apex_zone" {
  provider     = aws.account
  name         = local.apex_domain
  private_zone = var.private_zone
}


