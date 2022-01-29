################################################################################
# DNS Record Outputs
################################################################################
output "record_name" {
  value = [for v in aws_route53_record.record : v.name]
}

output "record_fqdn" {
  value = [for v in aws_route53_record.record : v.fqdn]
}

output "record_zone_id" {
  value = [for v in aws_route53_record.record : v.zone_id]
}


################################################################################
# Health Check Outputs
################################################################################
output "health_check_id" {
  value = [for v in aws_route53_health_check.health_check : v.id]
}

output "health_check_name" {
  value = [for v in aws_route53_health_check.health_check : v.reference_name]
}
