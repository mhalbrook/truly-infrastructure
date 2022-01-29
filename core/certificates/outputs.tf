################################################################################
# Certificate Outputs
################################################################################
output "truly_arn" {
  value = module.truly.arn
}

output "truly_domain" {
  value = module.truly.domain_name
}