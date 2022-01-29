###############################################################################
# VPC Outputs
###############################################################################
output "vpc_name" {
  value = local.full_vpc_name
}

output "vpc_arn" {
  value = aws_vpc.vpc.arn
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "vpc_cidr" {
  value = aws_vpc.vpc.cidr_block
}

output "availability_zones" {
  value = local.availability_zones
}


###############################################################################
# Gateway Outputs
###############################################################################
#############################################################
# Internet Gateway Outputs
#############################################################
output "internet_gateway_arn" {
  value = [for v in aws_internet_gateway.main : v.arn]
}

output "internet_gateway_id" {
  value = [for v in aws_internet_gateway.main : v.id]
}

#############################################################
# NAT Gateway Outputs
#############################################################
output "nat_gateway_ids" {
  value = [for v in aws_nat_gateway.ngw : v.id]
}

output "nat_gateway_public_ips" {
  value = [for v in aws_nat_gateway.ngw : v.public_ip]
}

output "nat_gateway_private_ips" {
  value = [for v in aws_nat_gateway.ngw : v.private_ip]
}

#############################################################
# Transit Gateway Outputs
#############################################################
output "transit_gateway_id" {
  value = var.transit_gateway_id
}


###############################################################################
# Subnet Outputs
###############################################################################
output "subnet_ids" {
  value = {
    public  = [for s in aws_subnet.public : s.id]
    private = [for s in aws_subnet.private : s.id]
    data    = [for s in aws_subnet.data : s.id]
    transit = [for s in aws_subnet.transit : s.id]
  }
}

output "subnet_cidrs" {
  value = {
    public  = [for s in aws_subnet.public : s.cidr_block]
    private = [for s in aws_subnet.private : s.cidr_block]
    data    = [for s in aws_subnet.data : s.cidr_block]
    transit = [for s in aws_subnet.transit : s.cidr_block]
  }
}


###############################################################################
# NACL Outputs
###############################################################################
output "nacl_arns" {
  value = {
    public  = aws_network_acl.public.arn
    private = aws_network_acl.private.arn
    data    = aws_network_acl.data.arn
    transit = aws_network_acl.transit.arn
  }
}


output "nacl_id" {
  value = {
    public  = aws_network_acl.public.id
    private = aws_network_acl.private.id
    data    = aws_network_acl.data.id
    transit = aws_network_acl.transit.id
  }
}


###############################################################################
# Route Table Outputs
###############################################################################
output "route_table_arns" {
  value = {
    public  = [for r in aws_route_table.public : r.arn]
    private = [for r in aws_route_table.private : r.arn]
    data    = [for r in aws_route_table.data : r.arn]
    transit = [for r in aws_route_table.transit : r.arn]
  }
}

output "route_table_ids" {
  value = {
    public  = [for r in aws_route_table.public : r.id]
    private = [for r in aws_route_table.private : r.id]
    data    = [for r in aws_route_table.data : r.id]
    transit = [for r in aws_route_table.transit : r.id]
  }
}


###############################################################################
# VPC Endpoint Security Group Outputs
###############################################################################
output "vpc_endpoint_security_group_name" {
  value = aws_security_group.endpoints.name
}

output "vpc_endpoint_security_group_arn" {
  value = aws_security_group.endpoints.arn
}

output "vpc_endpoint_security_group_id" {
  value = aws_security_group.endpoints.id
}


###############################################################################
# Route 53 Resolver Outputs
###############################################################################
output "route53_resolver_endpoint_arn" {
  value = try(aws_route53_resolver_endpoint.resolver[0].arn, null)
}

output "route53_resolver_endpoint_id" {
  value = try(aws_route53_resolver_endpoint.resolver[0].id, null)
}

output "route53_resolver_endpoint_ips" {
  value = try([for v in aws_route53_resolver_endpoint.resolver[0].ip_address : v.ip], null)
}


###############################################################################
# Route 53 Resolver Rule Outputs
###############################################################################
output "route53_resolver_rule_name" {
  value = try(aws_route53_resolver_rule.domain[0].name, null)
}

output "route53_resolver_rule_arn" {
  value = try(aws_route53_resolver_rule.domain[0].arn, null)
}

output "route53_resolver_rule_id" {
  value = try(aws_route53_resolver_rule.domain[0].id, null)
}

output "route53_resolver_rule_domain_name" {
  value = try(aws_route53_resolver_rule.domain[0].domain_name, null)
}


###############################################################################
# Route 53 Resolver Security Group Outputs
###############################################################################
output "route53_resolver_security_group_name" {
  value = try(aws_security_group.resolver[0].name, null)
}

output "route53_resolver_security_group_arn" {
  value = try(aws_security_group.resolver[0].arn, null)
}

output "route53_resolver_security_group_id" {
  value = try(aws_security_group.resolver[0].id, null)
}