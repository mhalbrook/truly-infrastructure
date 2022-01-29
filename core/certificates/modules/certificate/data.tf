################################################################################
# Hosted Zone Inputs
################################################################################
data "aws_route53_zone" "validation" {
  provider     = aws.networking
  name         = local.certificate_type == "public" ? local.validation_domain : "myvolly.com" # if certificate is Private find myvolly.com as validation records are not required, hwoever, this data block must resolve
  private_zone = false
}
