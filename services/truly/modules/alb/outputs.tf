################################################################################
# Load Balancer Outputs
################################################################################
output "load_balancer_dns_name" {
  description = "DNS name of the Load Balancer"
  value       = aws_lb.load_balancer.dns_name
}

output "load_balancer_arn" {
  description = "ARN of the Load Balancer"
  value       = aws_lb.load_balancer.arn
}

output "load_balancer_zone_id" {
  description = "ID of the zone which Load Balancer is provisioned"
  value       = aws_lb.load_balancer.zone_id
}

#############################################################
# Load Balancer Listener Outputs
#############################################################
output "load_balancer_listener_id" {
  description = "ID of the https Listener associated with the Load Balancer"
  value       = [for v in aws_lb_listener.listener : v.id]
}

output "load_balancer_listener_arn" {
  description = "ARN of the https Listener associated with the Load Balancer"
  value       = [for v in aws_lb_listener.listener : v.arn]
}

output "load_balancer_http_listener_id" {
  description = "ID of the http Listener associated with the Load Balancer"
  value       = [for v in aws_lb_listener.listener : v.id]
}

output "load_balancer_http_listener_arn" {
  description = "ARN of the http Listener associated with the Load Balancer"
  value       = [for v in aws_lb_listener.listener : v.arn]
}


################################################################################
# Target Group Outputs
################################################################################
output "target_group_names" {
  description = "List of friendly names of the Target Groups associated with the Load Balancer"
  value       = [for v in aws_lb_target_group.targets : v.name]
}

output "target_group_arns" {
  description = "List of ARNs of the Target Groups associated with the Load Balancer"
  value       = [for v in aws_lb_target_group.targets : v.arn]
}

output "target_group_ids" {
  description = "List of IDs of the Target Groups associated with the Load Balancer"
  value       = [for v in aws_lb_target_group.targets : v.id]
}


################################################################################
# Security Group Outputs
################################################################################
output "load_balancer_security_group_name" {
  description = "Friendly name of the security group attached to the Load Balancer"
  value       = [for v in aws_security_group.security_group : v.name]
}

output "load_balancer_security_group_arn" {
  description = "ARN of the security group attached to the Load Balancer"
  value       = [for v in aws_security_group.security_group : v.arn]
}

output "load_balancer_security_group_id" {
  description = "ID of the security group attached to the Load Balancer"
  value       = [for v in aws_security_group.security_group : v.id]
}


################################################################################
# Elastic IP Outputs
################################################################################
output "elastic_ip_allocation_ids" {
  description = "ID representing the allocation of the Elastic IPs for use with instances inside a VPC (network load balancers only)"
  value       = [for v in aws_eip.eip : v.id]
}

output "elastic_ip_ids" {
  description = "ID of the Elastic IPs associated to the load balancer (network load balancers only)"
  value       = [for v in aws_eip.eip : v.id]
}

output "elastic_ip_public_ips" {
  description = "Public IPs of the Elastic IPs associated to the load balancer (network load balancers only)"
  value       = [for v in aws_eip.eip : v.id]
}

output "elastic_ip_private_ips" {
  description = "Private IPs of the Elastic IPs associated to the load balancer (network load balancers only)"
  value       = [for v in aws_eip.eip : v.id]
}

################################################################################
# Global Accelerator Outputs
################################################################################
output "accelerator_id" {
  description = "ID of the global accelerator associated with the Load Balancer"
  value       = [for v in aws_globalaccelerator_accelerator.accelerator : v.id]
}

output "accelerator_name" {
  description = "Friendly Name of the global accelerator associated with the Load Balancer"
  value       = [for v in aws_globalaccelerator_accelerator.accelerator : v.name]
}

output "accelerator_dns_name" {
  description = "DNS Name of the global accelerator associated with the Load Balancer"
  value       = [for v in aws_globalaccelerator_accelerator.accelerator : v.dns_name]
}

output "accelerator_hosted_zone_id" {
  description = "ID of the Hosted Zone associated with the Load Balancer"
  value       = [for v in aws_globalaccelerator_accelerator.accelerator : v.hosted_zone_id]
}

output "accelerator_ip_sets" {
  description = "Map of the IP Details for the IP Addresses associated with the Load Balancer"
  value       = [for v in aws_globalaccelerator_accelerator.accelerator : v.ip_sets]
}

#############################################################
# Global Accelerator Listener Outputs
#############################################################
output "accelerator_listener_id" {
  description = "ID of the global accelerator listener"
  value       = [for v in aws_globalaccelerator_listener.listener : v.id]
}

output "accelerator_listener_arn" {
  description = "ARN of the global accelerator listener"
  value       = [for v in aws_globalaccelerator_listener.listener : v.id]
}

#############################################################
# Global Accelerator Endpoint Group Outputs
#############################################################
output "accelerator_endpoint_group_id" {
  description = "ID of the global accelerator endpoint group"
  value       = [for v in aws_globalaccelerator_endpoint_group.endpoint_group : v.id]
}

output "accelerator_endpoint_group_arn" {
  description = "ARN of the global accelerator endpoint group"
  value       = [for v in aws_globalaccelerator_endpoint_group.endpoint_group : v.arn]
}
