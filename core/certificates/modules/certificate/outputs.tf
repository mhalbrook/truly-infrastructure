################################################################################
# Certificate Outputs
################################################################################
output "arn" {
  value = aws_acm_certificate.certificate.arn
}

output "id" {
  value = aws_acm_certificate.certificate.id
}

output "domain_name" {
  value = aws_acm_certificate.certificate.domain_name
}

output "domain_validation_options" {
  value = aws_acm_certificate.certificate.domain_validation_options
}

output "validation_domain" {
  value = local.validation_domain
}

output "validation_records" {
  value = local.validation_records
}