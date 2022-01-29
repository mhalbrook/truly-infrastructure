################################################################################
# Locals
################################################################################
#############################################################
# Certificate Locals
#############################################################
locals {
  certificate_type = var.certificate_authority_arn != null ? "private" : "public" # set whether to create a private of public certififcate based on whether a Certificate Authority ARN is provided                                                                                                    # do not set validation method for Private Certificates as validation is not required
}

#############################################################
# Validation Locals
#############################################################
locals {
  validation_domain = var.validation_domain == null ? join(".", slice(split(".", var.domain_name), length(split(".", var.domain_name)) - 2, length(split(".", var.domain_name)))) : var.validation_domain # if validation domain is not provided, use the root of the Provided Domain name for validation (i.e. one.example.com becomes example.com)
  validation_method = local.certificate_type == "private" ? null : "DNS"
  validation_records = { for v in aws_acm_certificate.certificate.domain_validation_options : # build map of arguments required for Certificate Validation DNS Records
    v.domain_name => {
      name   = v.resource_record_name
      record = v.resource_record_value
      type   = v.resource_record_type
    } if v.domain_name != format("*.%s", var.domain_name)
  }
}

################################################################################
# Certificate
################################################################################
resource "aws_acm_certificate" "certificate" {
  provider                  = aws.account
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = local.validation_method
  certificate_authority_arn = var.certificate_authority_arn
  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
      type        = local.certificate_type
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

#############################################################
# Certificate Validation
#############################################################
resource "aws_route53_record" "certificate_validation" {
  provider = aws.networking
  for_each = local.certificate_type == "public" ? local.validation_records : {}
  zone_id  = data.aws_route53_zone.validation.zone_id
  ttl      = var.validation_ttl
  name     = each.value.name
  type     = each.value.type
  records  = [each.value.record]
}

resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.account
  count                   = local.certificate_type == "public" ? 1 : 0
  certificate_arn         = aws_acm_certificate.certificate.arn
  validation_record_fqdns = [for v in aws_route53_record.certificate_validation : v.fqdn]
}
