################################################################################
# Locals
################################################################################
#############################################################
# Global Locals
#############################################################
locals {
  full_vpc_name      = format("%s-%s", var.vpc_name, var.environment)
  availability_zones = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)
}

#############################################################
# Subnet Locals
#############################################################
locals {
  public_subnets = { # Create map of both public subnets, setting the subnet name as the key and a map of Subnet IDs and Availability Zones as the value
    for s in aws_subnet.public :
    s.tags.Name => {
      subnet_id         = s.id
      cidr_block        = s.cidr_block
      availability_zone = s.availability_zone
    }
  }

  private_subnets = { # Create map of both private subnets, setting the subnet name as the key and a map of Subnet IDs and Availability Zones as the value
    for s in aws_subnet.private :
    s.tags.Name => {
      subnet_id         = s.id
      cidr_block        = s.cidr_block
      availability_zone = s.availability_zone
    }
  }

  data_subnets = { # Create map of both data subnets, setting the subnet name as the key and a map of Subnet IDs and Availability Zones as the value
    for s in aws_subnet.data :
    s.tags.Name => {
      subnet_id         = s.id
      cidr_block        = s.cidr_block
      availability_zone = s.availability_zone
    }
  }

  transit_subnets = { # Create map of both Transit subnets, setting the subnet name as the key and a map of Subnet IDs and Availability Zones as the value
    for s in aws_subnet.transit :
    s.tags.Name => {
      subnet_id         = s.id
      cidr_block        = s.cidr_block
      availability_zone = s.availability_zone
    }
  }
}

#############################################################
# Route Table Locals
#############################################################
locals {
  public_route_tables = { # Create map of both public route tables, setting the route table name as the key and a map of Route Table IDs.
    for r in aws_route_table.public :
    r.tags.Name => {
      route_table_id    = r.id
      availability_zone = r.tags.availability_zone
    }
  }

  private_route_tables = { # Create map of both private route tables, setting the route table name as the key and a map of Route Table IDs.
    for r in aws_route_table.private :
    r.tags.Name => {
      route_table_id    = r.id
      availability_zone = r.tags.availability_zone
    }
  }

  data_route_tables = { # Create map of both data route tables, setting the route table name as the key and a map of Route Table IDs.
    for r in aws_route_table.data :
    r.tags.Name => {
      route_table_id    = r.id
      availability_zone = r.tags.availability_zone
    }
  }

  transit_route_tables = { # Create map of both Transit route tables, setting the route table name as the key and a map of Route Table IDs.
    for r in aws_route_table.transit :
    r.tags.Name => {
      route_table_id    = r.id
      availability_zone = r.tags.availability_zone
    }
  }
}

#############################################################
# NACL Locals
#############################################################
locals {
  private_nacl_database = {                                                                    # create matrix of database ports, matched to each Database Subnet to create NACl rules for Private Subnets when database ports are provided
    for pair in setproduct(var.database_ports, [for v in local.data_subnets : v.cidr_block]) : # setproduct creates a set of lists with two elements each; a database port and a subnet ID
    format("%s_%s", pair[0], pair[1]) => {                                                     # create map key of port_subnetID
      port       = pair[0]
      cidr_block = pair[1]
    }
  }

  data_nacl_database = {                                                                          # create matrix of database ports, matched to each Private Subnet to create NACl rules for Data Subnets when database ports are provided
    for pair in setproduct(var.database_ports, [for v in local.private_subnets : v.cidr_block]) : # setproduct creates a set of lists with two elements each; a database port and a subnet ID
    format("%s_%s", pair[0], pair[1]) => {                                                        # create map key of port_subnetID
      port       = pair[0]
      cidr_block = pair[1]
    }
  }

  public_nacl_application = {                                                                        # create matrix of application ports, matched to each Private Subnet to create NACl rules for Public Subnets when application ports are provided
    for pair in setproduct(var.application_ports, [for v in local.private_subnets : v.cidr_block]) : # setproduct creates a set of lists with two elements each; an application port and a subnet ID
    format("%s_%s", pair[0], pair[1]) => {                                                           # create map key of port_subnetID
      port       = pair[0]
      cidr_block = pair[1]
    }
  }

  private_nacl_application = {                                                                      # create matrix of application ports, matched to each Public Subnet to create NACl rules for Public Subnets when application ports are provided
    for pair in setproduct(var.application_ports, [for v in local.public_subnets : v.cidr_block]) : # setproduct creates a set of lists with two elements each; an application port and a subnet ID
    format("%s_%s", pair[0], pair[1]) => {                                                          # create map key of port_subnetID
      port       = pair[0]
      cidr_block = pair[1]
    }
  }
}


###############################################################################
# VPC
###############################################################################
resource "aws_vpc" "vpc" {
  provider             = aws.account
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = local.full_vpc_name
      environment = var.environment
    }
  )
}


################################################################################
# Route53 Resolver Endpoints
################################################################################
resource "aws_route53_resolver_endpoint" "resolver" {
  provider           = aws.account
  count              = var.domain_join == true ? 1 : 0
  name               = format("%s-resolver", local.full_vpc_name)
  direction          = "OUTBOUND"
  security_group_ids = [aws_security_group.resolver[0].id]

  dynamic "ip_address" {
    for_each = { for v in local.private_subnets : v.subnet_id => v.cidr_block }
    content {
      subnet_id = ip_address.key
      ip        = trimsuffix(cidrsubnet(ip_address.value, 8, 5), "/32")
    }
  }

  tags = merge(
    var.tags,
    {
      environment = terraform.workspace
    }
  )
}

#########################################
# Resolver Security Group
#########################################
resource "aws_security_group" "resolver" {
  provider    = aws.account
  count       = var.domain_join == true ? 1 : 0
  name        = format("%s-resolver-endpoints", local.full_vpc_name)
  description = "Controls access to Route53 DNS Resolver Endpoints"
  vpc_id      = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-resolver-endpoints", local.full_vpc_name)
      environment = var.environment
    }
  )
}

resource "aws_security_group_rule" "resolver_ingress_dns" {
  provider          = aws.account
  count             = var.domain_join == true ? 1 : 0
  type              = "ingress"
  description       = "inbound 53 from private and data subnets"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = [aws_vpc.vpc.cidr_block]
  security_group_id = aws_security_group.resolver[0].id
}

resource "aws_security_group_rule" "resolver_egress_domain" {
  provider          = aws.account
  count             = var.domain_join == true ? 1 : 0
  type              = "egress"
  description       = "Outbound 53 to Domain Controllers"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = formatlist("%s/32", var.domain_ips)
  security_group_id = aws_security_group.resolver[0].id
}

#########################################
# Resolver Rule
#########################################
resource "aws_route53_resolver_rule" "domain" {
  provider             = aws.account
  count                = var.domain_join == true ? 1 : 0
  name                 = format("%s-resolver-%s", local.full_vpc_name, replace(var.domain_name, ".", "-"))
  domain_name          = var.domain_name
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.resolver[0].id

  dynamic "target_ip" {
    for_each = toset(var.domain_ips)
    content {
      ip = target_ip.value
    }
  }

  tags = merge(
    var.tags,
    {
      environment = terraform.workspace
    }
  )
}

resource "aws_route53_resolver_rule_association" "domain" {
  provider         = aws.account
  count            = var.domain_join == true ? 1 : 0
  resolver_rule_id = aws_route53_resolver_rule.domain[0].id
  vpc_id           = aws_vpc.vpc.id
}

###############################################################################
# Transit Gateway Attachment
###############################################################################
resource "aws_ec2_transit_gateway_vpc_attachment" "attachment" {
  provider           = aws.account
  count              = var.transit_gateway_id != null ? 1 : 0
  subnet_ids         = [for s in local.transit_subnets : s.subnet_id]
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-tgw-attachment", local.full_vpc_name)
      environment = var.environment
    }
  )
}


###############################################################################
# Gateways
###############################################################################
#############################################################
# Internet Gateway
#############################################################
resource "aws_internet_gateway" "main" {
  provider = aws.account
  count    = var.internet_enabled ? 1 : 0
  vpc_id   = aws_vpc.vpc.id
  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-igw", local.full_vpc_name)
      environment = var.environment
    }
  )
}

#############################################################
# NAT Gateways
#############################################################
resource "aws_eip" "nat" {
  provider = aws.account
  for_each = var.internet_enabled == true ? local.public_subnets : {}
  vpc      = true

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-%s-ngw", each.value.availability_zone, local.full_vpc_name)
      environment       = var.environment
      availability_zone = each.value.availability_zone
    }
  )
}

resource "aws_nat_gateway" "ngw" {
  provider      = aws.account
  for_each      = var.internet_enabled == true ? local.public_subnets : {}
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.subnet_id
  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-%s-ngw", each.value.availability_zone, local.full_vpc_name)
      environment       = var.environment
      availability_zone = each.value.availability_zone
    }
  )
}


###############################################################################
# Subnets
###############################################################################
#############################################################
# Public subnets
#############################################################
resource "aws_subnet" "public" {
  provider          = aws.account
  for_each          = toset(local.availability_zones)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element([for num in range(10, 10 + var.availability_zone_count) : cidrsubnet(aws_vpc.vpc.cidr_block, 8, num)], index(local.availability_zones, each.value)) # Dynamically set subnet CIDRs with /24 subnet mask   # element([for num in range(10, 10 + var.availability_zone_count) : cidrsubnet(aws_vpc.vpc.cidr_block, 8, num)], count.index) 
  availability_zone = each.value

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-%s-public-subnet", each.value, local.full_vpc_name)
      environment       = var.environment
      layer             = "public"
      availability_zone = each.value
    }
  )
}

#############################################################
# Private subnets
#############################################################
resource "aws_subnet" "private" {
  provider          = aws.account
  for_each          = toset(local.availability_zones)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element([for num in range(20, 20 + var.availability_zone_count) : cidrsubnet(aws_vpc.vpc.cidr_block, 8, num)], index(local.availability_zones, each.value)) # Dynamically set subnet CIDRs with /24 subnet mask
  availability_zone = each.value

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-%s-private-subnet", each.value, local.full_vpc_name)
      environment       = var.environment
      layer             = "private"
      availability_zone = each.value
    }
  )
}

#############################################################
# Data subnets
#############################################################
resource "aws_subnet" "data" {
  provider          = aws.account
  for_each          = toset(local.availability_zones)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element([for num in range(30, 30 + var.availability_zone_count) : cidrsubnet(aws_vpc.vpc.cidr_block, 8, num)], index(local.availability_zones, each.value)) # Dynamically set subnet CIDRs with /24 subnet mask
  availability_zone = each.value

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-%s-data-subnet", each.value, local.full_vpc_name)
      environment       = var.environment
      layer             = "data"
      availability_zone = each.value
    }
  )
}

#############################################################
# Transit Gateway subnets
#############################################################
resource "aws_subnet" "transit" {
  provider          = aws.account
  for_each          = toset(local.availability_zones)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element([for num in range(40, 40 + var.availability_zone_count) : cidrsubnet(aws_vpc.vpc.cidr_block, 8, num)], index(local.availability_zones, each.value)) # Dynamically set subnet CIDRs with /24 subnet mask
  availability_zone = each.value

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-%s-transit-subnet", each.value, local.full_vpc_name)
      environment       = var.environment
      layer             = "transit"
      availability_zone = each.value
    }
  )
}


###############################################################################
# Route Tables and Default Routes
###############################################################################
#############################################################
# Publiс Route Tables
#############################################################
resource "aws_route_table" "public" {
  provider = aws.account
  for_each = local.public_subnets
  vpc_id   = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-%s-public-route-table", each.value.availability_zone, local.full_vpc_name)
      environment       = var.environment
      availability_zone = each.value.availability_zone
    }
  )
}

resource "aws_route_table_association" "public" {
  provider       = aws.account
  for_each       = local.public_route_tables
  subnet_id      = element([for s in local.public_subnets : s.subnet_id if s.availability_zone == each.value.availability_zone], 0)
  route_table_id = each.value.route_table_id
}

resource "aws_route" "public_internet_gateway" {
  provider               = aws.account
  for_each               = var.internet_enabled == true ? local.public_route_tables : {}
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[0].id
  route_table_id         = each.value.route_table_id
}

resource "aws_route" "public_campus_data" {
  provider               = aws.account
  for_each               = var.transit_gateway_id != null ? local.public_route_tables : {}
  destination_cidr_block = element(var.campus_cidrs, 0)
  transit_gateway_id     = aws_ec2_transit_gateway_vpc_attachment.attachment[0].transit_gateway_id
  route_table_id         = each.value.route_table_id
}

resource "aws_route" "public_campus_vpn" {
  provider               = aws.account
  for_each               = var.transit_gateway_id != null ? local.public_route_tables : {}
  destination_cidr_block = element(var.campus_cidrs, 1)
  transit_gateway_id     = aws_ec2_transit_gateway_vpc_attachment.attachment[0].transit_gateway_id
  route_table_id         = each.value.route_table_id
}


#############################################################
# Private Route Tables
#############################################################
resource "aws_route_table" "private" {
  provider = aws.account
  for_each = local.private_subnets
  vpc_id   = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-%s-private-route-table", each.value.availability_zone, local.full_vpc_name)
      environment       = var.environment
      availability_zone = each.value.availability_zone
    }
  )
}

resource "aws_route_table_association" "private" {
  provider       = aws.account
  for_each       = local.private_route_tables
  subnet_id      = element([for s in local.private_subnets : s.subnet_id if s.availability_zone == each.value.availability_zone], 0)
  route_table_id = each.value.route_table_id
}

resource "aws_route" "private_nat_gateway" {
  provider               = aws.account
  for_each               = var.internet_enabled == true ? local.private_route_tables : {}
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element([for v in aws_nat_gateway.ngw : v.id if v.tags.availability_zone == each.value.availability_zone], 0)
  route_table_id         = each.value.route_table_id
}

resource "aws_route" "private_campus_data" {
  provider               = aws.account
  for_each               = var.transit_gateway_id != null ? local.private_route_tables : {}
  destination_cidr_block = element(var.campus_cidrs, 0)
  transit_gateway_id     = aws_ec2_transit_gateway_vpc_attachment.attachment[0].transit_gateway_id
  route_table_id         = each.value.route_table_id
}

resource "aws_route" "private_campus_vpn" {
  provider               = aws.account
  for_each               = var.transit_gateway_id != null ? local.private_route_tables : {}
  destination_cidr_block = element(var.campus_cidrs, 1)
  transit_gateway_id     = aws_ec2_transit_gateway_vpc_attachment.attachment[0].transit_gateway_id
  route_table_id         = each.value.route_table_id
}

resource "aws_route" "private_domain" {
  provider               = aws.account
  for_each               = var.domain_join == true && var.transit_gateway_id != null ? local.private_route_tables : {}
  destination_cidr_block = var.domain_cidr
  transit_gateway_id     = aws_ec2_transit_gateway_vpc_attachment.attachment[0].transit_gateway_id
  route_table_id         = each.value.route_table_id
}


#############################################################
# Data Route Tables
#############################################################
resource "aws_route_table" "data" {
  provider = aws.account
  for_each = local.data_subnets
  vpc_id   = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-%s-data-route-table", each.value.availability_zone, local.full_vpc_name)
      environment       = var.environment
      availability_zone = each.value.availability_zone
    }
  )
}

resource "aws_route_table_association" "data" {
  provider       = aws.account
  for_each       = local.data_route_tables
  subnet_id      = element([for s in local.data_subnets : s.subnet_id if s.availability_zone == each.value.availability_zone], 0)
  route_table_id = each.value.route_table_id
}

resource "aws_route" "data_nat_gateway" {
  provider               = aws.account
  for_each               = var.internet_enabled == true ? local.data_route_tables : {}
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element([for v in aws_nat_gateway.ngw : v.id if v.tags.availability_zone == each.value.availability_zone], 0)
  route_table_id         = each.value.route_table_id
}

resource "aws_route" "data_campus_data" {
  provider               = aws.account
  for_each               = var.transit_gateway_id != null ? local.data_route_tables : {}
  destination_cidr_block = element(var.campus_cidrs, 0)
  transit_gateway_id     = aws_ec2_transit_gateway_vpc_attachment.attachment[0].transit_gateway_id
  route_table_id         = each.value.route_table_id
}

resource "aws_route" "data_campus_vpn" {
  provider               = aws.account
  for_each               = var.transit_gateway_id != null ?  local.data_route_tables : {}
  destination_cidr_block = element(var.campus_cidrs, 1)
  transit_gateway_id     = aws_ec2_transit_gateway_vpc_attachment.attachment[0].transit_gateway_id
  route_table_id         = each.value.route_table_id
}

resource "aws_route" "data_domain" {
  provider               = aws.account
  for_each               = var.domain_join == true && var.transit_gateway_id != null ? local.data_route_tables : {}
  destination_cidr_block = var.domain_cidr
  transit_gateway_id     = aws_ec2_transit_gateway_vpc_attachment.attachment[0].transit_gateway_id
  route_table_id         = each.value.route_table_id
}

#############################################################
# Transit Gateway routes
#############################################################
resource "aws_route_table" "transit" {
  provider = aws.account
  for_each = local.transit_subnets
  vpc_id   = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name              = format("%s-%s-transit-route-table", each.value.availability_zone, local.full_vpc_name)
      environment       = var.environment
      availability_zone = each.value.availability_zone
    }
  )
}

resource "aws_route_table_association" "transit" {
  provider       = aws.account
  for_each       = local.transit_route_tables
  subnet_id      = element([for s in local.transit_subnets : s.subnet_id if s.availability_zone == each.value.availability_zone], 0)
  route_table_id = each.value.route_table_id
}

resource "aws_route" "transit" {
  provider               = aws.account
  for_each               = var.transit_gateway_id != null ? local.transit_route_tables : {}
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = aws_ec2_transit_gateway_vpc_attachment.attachment[0].transit_gateway_id
  route_table_id         = each.value.route_table_id
}



###############################################################################
# Network Access Control Lists (NACLs)
###############################################################################
#############################################################
# Public NACL
#############################################################
resource "aws_network_acl" "public" {
  provider   = aws.account
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [for s in local.public_subnets : s.subnet_id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-public-nacl", local.full_vpc_name)
      environment = var.environment
    }
  )
}

##########################################
# Public NACL Ingress Rules
##########################################
resource "aws_network_acl_rule" "public_inbound_https" {
  provider       = aws.account
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "public_inbound_http" {
  provider       = aws.account
  network_acl_id = aws_network_acl.public.id
  rule_number    = 101
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_inbound_ephemeral" {
  provider       = aws.account
  network_acl_id = aws_network_acl.public.id
  rule_number    = 105
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "public_inbound_dns" {
  provider       = aws.account
  count          = var.domain_join == true ? 1 : 0
  network_acl_id = aws_network_acl.public.id
  rule_number    = 305
  egress         = false
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.vpc.cidr_block
  from_port      = 53
  to_port        = 53
}

resource "aws_network_acl_rule" "public_inbound_icmp" {
  provider       = aws.account
  count          = var.enable_icmp == true ? length(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs])) : 0
  network_acl_id = aws_network_acl.public.id
  rule_number    = element(range(600, 600 + length(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs]))), count.index)
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = element(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs]), count.index)
  from_port      = 0
  to_port        = 0
  icmp_type      = -1
  icmp_code      = -1
}


##########################################
# Public NACL Egress Rules
##########################################
resource "aws_network_acl_rule" "public_outbound_https" {
  provider       = aws.account
  network_acl_id = aws_network_acl.public.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "public_outbound_http" {
  provider       = aws.account
  network_acl_id = aws_network_acl.public.id
  rule_number    = 101
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_outbound_ephemeral" {
  provider       = aws.account
  network_acl_id = aws_network_acl.public.id
  rule_number    = 105
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "public_outbound_application" {
  provider       = aws.account
  for_each       = local.public_nacl_application
  network_acl_id = aws_network_acl.public.id
  rule_number    = element(range(200, 200 + length(local.public_nacl_application)), index(keys(local.public_nacl_application), each.key))
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.port
  to_port        = each.value.port
}

resource "aws_network_acl_rule" "public_outbound_icmp" {
  provider       = aws.account
  count          = var.enable_icmp == true ? length(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs])) : 0
  network_acl_id = aws_network_acl.public.id
  rule_number    = element(range(600, 600 + length(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs]))), count.index)
  egress         = true
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = element(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs]), count.index)
  from_port      = 0
  to_port        = 0
  icmp_type      = -1
  icmp_code      = -1
}


#############################################################
# Private NACL
#############################################################
resource "aws_network_acl" "private" {
  provider   = aws.account
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [for s in local.private_subnets : s.subnet_id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-private-nacl", local.full_vpc_name)
      environment = var.environment
    }
  )
}

##########################################
# Private NACL Ingress Rules
##########################################
resource "aws_network_acl_rule" "private_inbound_ephemeral" {
  provider       = aws.account
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_inbound_application" {
  provider       = aws.account
  for_each       = local.private_nacl_application
  network_acl_id = aws_network_acl.private.id
  rule_number    = element(range(200, 200 + length(local.private_nacl_application)), index(keys(local.private_nacl_application), each.key))
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.port
  to_port        = each.value.port
}

resource "aws_network_acl_rule" "private_inbound_domain" {
  provider       = aws.account
  count          = var.domain_join == true ? 1 : 0
  network_acl_id = aws_network_acl.private.id
  rule_number    = 305
  egress         = false
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = var.domain_cidr
  from_port      = -1
  to_port        = -1
}

resource "aws_network_acl_rule" "private_inbound_private" {
  provider       = aws.account
  for_each       = local.private_subnets
  network_acl_id = aws_network_acl.private.id
  rule_number    = element(range(310, 310 + length(local.private_subnets)), index(keys(local.private_subnets), each.key))
  egress         = false
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = -1
  to_port        = -1
}

resource "aws_network_acl_rule" "private_inbound_icmp" {
  provider       = aws.account
  count          = var.enable_icmp == true ? length(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs])) : 0
  network_acl_id = aws_network_acl.private.id
  rule_number    = element(range(600, 600 + length(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs]))), count.index)
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = element(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs]), count.index)
  from_port      = 0
  to_port        = 0
  icmp_type      = -1
  icmp_code      = -1
}

##########################################
# Private NACL Egress Rules
##########################################
resource "aws_network_acl_rule" "private_outbound_https" {
  provider       = aws.account
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "private_outbound_http" {
  provider       = aws.account
  network_acl_id = aws_network_acl.private.id
  rule_number    = 101
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "private_outbound_ephemeral" {
  provider       = aws.account
  network_acl_id = aws_network_acl.private.id
  rule_number    = 105
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_outbound_database" {
  provider       = aws.account
  for_each       = local.private_nacl_database
  network_acl_id = aws_network_acl.private.id
  rule_number    = element(range(200, 200 + length(local.private_nacl_database)), index(keys(local.private_nacl_database), each.key))
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.port
  to_port        = each.value.port
}

resource "aws_network_acl_rule" "private_outbound_dns" {
  provider       = aws.account
  count          = var.domain_join == true ? 1 : 0
  network_acl_id = aws_network_acl.private.id
  rule_number    = 300
  egress         = true
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.vpc.cidr_block
  from_port      = 53
  to_port        = 53
}

resource "aws_network_acl_rule" "private_outbound_domain" {
  provider       = aws.account
  count          = var.domain_join == true ? 1 : 0
  network_acl_id = aws_network_acl.private.id
  rule_number    = 305
  egress         = true
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = var.domain_cidr
  from_port      = -1
  to_port        = -1
}

resource "aws_network_acl_rule" "private_outbound_private" {
  provider       = aws.account
  for_each       = local.private_subnets
  network_acl_id = aws_network_acl.private.id
  rule_number    = element(range(310, 310 + length(local.private_subnets)), index(keys(local.private_subnets), each.key))
  egress         = true
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = -1
  to_port        = -1
}

resource "aws_network_acl_rule" "private_outbound_icmp" {
  provider       = aws.account
  count          = var.enable_icmp == true ? length(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs])) : 0
  network_acl_id = aws_network_acl.private.id
  rule_number    = element(range(600, 600 + length(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs]))), count.index)
  egress         = true
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = element(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs]), count.index)
  from_port      = 0
  to_port        = 0
  icmp_type      = -1
  icmp_code      = -1
}


#############################################################
# Data NACL
#############################################################
resource "aws_network_acl" "data" {
  provider   = aws.account
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [for s in local.data_subnets : s.subnet_id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-data-nacl", local.full_vpc_name)
      environment = var.environment
    }
  )
}

##########################################
# Data NACL Ingress Rules
##########################################
resource "aws_network_acl_rule" "data_inbound_ephemeral" {
  provider       = aws.account
  network_acl_id = aws_network_acl.data.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "data_inbound_private" {
  provider       = aws.account
  for_each       = local.data_nacl_database
  network_acl_id = aws_network_acl.data.id
  rule_number    = element(range(200, 200 + length(local.data_nacl_database)), index(keys(local.data_nacl_database), each.key))
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = each.value.port
  to_port        = each.value.port
}

resource "aws_network_acl_rule" "data_inbound_domain" {
  provider       = aws.account
  count          = var.domain_join == true ? 1 : 0
  network_acl_id = aws_network_acl.data.id
  rule_number    = 305
  egress         = false
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = var.domain_cidr
  from_port      = -1
  to_port        = -1
}

resource "aws_network_acl_rule" "data_inbound_data" {
  provider       = aws.account
  for_each       = local.data_subnets
  network_acl_id = aws_network_acl.data.id
  rule_number    = element(range(310, 310 + length(local.data_subnets)), index(keys(local.data_subnets), each.key))
  egress         = false
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = -1
  to_port        = -1
}

resource "aws_network_acl_rule" "data_inbound_icmp" {
  provider       = aws.account
  count          = var.enable_icmp == true ? length(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs])) : 0
  network_acl_id = aws_network_acl.data.id
  rule_number    = element(range(600, 600 + length(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs]))), count.index)
  egress         = false
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = element(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs]), count.index)
  from_port      = 0
  to_port        = 0
  icmp_type      = -1
  icmp_code      = -1
}


##########################################
# Data NACL Egress Rules
##########################################
resource "aws_network_acl_rule" "data_outbound_https" {
  provider       = aws.account
  network_acl_id = aws_network_acl.data.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "data_outbound_http" {
  provider       = aws.account
  network_acl_id = aws_network_acl.data.id
  rule_number    = 101
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "data_outbound_ephemeral" {
  provider       = aws.account
  network_acl_id = aws_network_acl.data.id
  rule_number    = 105
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "data_outbound_dns" {
  provider       = aws.account
  count          = var.domain_join == true ? 1 : 0
  network_acl_id = aws_network_acl.data.id
  rule_number    = 300
  egress         = true
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = aws_vpc.vpc.cidr_block
  from_port      = 53
  to_port        = 53
}

resource "aws_network_acl_rule" "data_outbound_domain" {
  provider       = aws.account
  count          = var.domain_join == true ? 1 : 0
  network_acl_id = aws_network_acl.data.id
  rule_number    = 305
  egress         = true
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = var.domain_cidr
  from_port      = -1
  to_port        = -1
}

resource "aws_network_acl_rule" "data_outbound_data" {
  provider       = aws.account
  for_each       = local.data_subnets
  network_acl_id = aws_network_acl.data.id
  rule_number    = element(range(310, 310 + length(local.data_subnets)), index(keys(local.data_subnets), each.key))
  egress         = true
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = each.value.cidr_block
  from_port      = -1
  to_port        = -1
}

resource "aws_network_acl_rule" "data_outbound_icmp" {
  provider       = aws.account
  count          = var.enable_icmp == true ? length(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs])) : 0
  network_acl_id = aws_network_acl.data.id
  rule_number    = element(range(600, 600 + length(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs]))), count.index)
  egress         = true
  protocol       = "icmp"
  rule_action    = "allow"
  cidr_block     = element(flatten([aws_vpc.vpc.cidr_block, var.campus_cidrs]), count.index)
  from_port      = 0
  to_port        = 0
  icmp_type      = -1
  icmp_code      = -1
}


#############################################################
# Transit NACL
#############################################################
resource "aws_network_acl" "transit" {
  provider   = aws.account
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [for s in local.transit_subnets : s.subnet_id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-transit-nacl", local.full_vpc_name)
      environment = var.environment
    }
  )
}

##########################################
# Transit NACL Ingress Rules
##########################################
resource "aws_network_acl_rule" "transit_inbound" {
  provider       = aws.account
  network_acl_id = aws_network_acl.transit.id
  rule_number    = 100
  egress         = false
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = -1
  to_port        = -1
}

##########################################
# Transit NACL Egress Rules
##########################################
resource "aws_network_acl_rule" "transit_outbound" {
  provider       = aws.account
  network_acl_id = aws_network_acl.transit.id
  rule_number    = 100
  egress         = true
  protocol       = -1
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = -1
  to_port        = -1
}


###############################################################################
# VPC Endpoints
###############################################################################
############################################################
# Gateway Endpoints
############################################################
#########################################
# S3 Endpoint
#########################################
resource "aws_vpc_endpoint" "s3" {
  provider     = aws.account
  vpc_id       = aws_vpc.vpc.id
  service_name = format("com.amazonaws.%s.s3", data.aws_region.region.name)

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-s3-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

resource "aws_vpc_endpoint_route_table_association" "s3" {
  provider        = aws.account
  for_each        = merge(local.public_route_tables, local.private_route_tables, local.data_route_tables)
  route_table_id  = each.value.route_table_id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

#########################################
# DynamoDB Endpoint
#########################################
resource "aws_vpc_endpoint" "dynamodb" {
  provider     = aws.account
  vpc_id       = aws_vpc.vpc.id
  service_name = format("com.amazonaws.%s.dynamodb", data.aws_region.region.name)

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-dynamodb-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb" {
  provider        = aws.account
  for_each        = merge(local.public_route_tables, local.private_route_tables, local.data_route_tables)
  route_table_id  = each.value.route_table_id
  vpc_endpoint_id = aws_vpc_endpoint.dynamodb.id
}


############################################################
# Interface Endpoints
############################################################
#########################################
# Cloudwatch Endpoints
#########################################
resource "aws_vpc_endpoint" "cloudwatch" {
  provider            = aws.account
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.logs", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.public_subnets : s.subnet_id]
  security_group_ids  = [aws_security_group.endpoints.id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-cloudwatch-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

#########################################
# EC2 Endpoints
#########################################
resource "aws_vpc_endpoint" "ec2" {
  provider            = aws.account
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.ec2", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.private_subnets : s.subnet_id] # Only attached to Private subnet as data subnet has access to communicate with private-subnet endpoint via 443
  security_group_ids  = [aws_security_group.endpoints.id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-ec2-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

resource "aws_vpc_endpoint" "autoscaling" {
  provider            = aws.account
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.autoscaling", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.private_subnets : s.subnet_id] # Only attached to Private subnet as data subnet has access to communicate with private-subnet endpoint via 443
  security_group_ids  = [aws_security_group.endpoints.id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-autoscaling-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

resource "aws_vpc_endpoint" "ebs" {
  provider            = aws.account
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.ebs", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.private_subnets : s.subnet_id] # Only attached to Private subnet as data subnet has access to communicate with private-subnet endpoint via 443
  security_group_ids  = [aws_security_group.endpoints.id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-ebs-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

#########################################
# ECR Endpoints
#########################################
resource "aws_vpc_endpoint" "ecr_dkr" {
  provider            = aws.account
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.ecr.dkr", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.private_subnets : s.subnet_id] # Only attached to Private subnet as data subnet has access to communicate with private-subnet endpoint via 443
  security_group_ids  = [aws_security_group.endpoints.id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-ecrdkr-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

resource "aws_vpc_endpoint" "ecr_api" {
  provider            = aws.account
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.ecr.api", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.private_subnets : s.subnet_id] # Only attached to Private subnet as data subnet has access to communicate with private-subnet endpoint via 443
  security_group_ids  = [aws_security_group.endpoints.id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-ecrapi-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}


#########################################
# App Mesh Endpoints
#########################################
resource "aws_vpc_endpoint" "appmesh" {
  provider            = aws.account
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.appmesh-envoy-management", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.private_subnets : s.subnet_id] # Only attached to Private subnet as data subnet has access to communicate with private-subnet endpoint via 443
  security_group_ids  = [aws_security_group.endpoints.id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-appmesh-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

#########################################
# Private Certificate Authority Endpoints
#########################################
resource "aws_vpc_endpoint" "private_ca" {
  provider            = aws.account
  vpc_id              = aws_vpc.vpc.id
  service_name        = format("com.amazonaws.%s.acm-pca", data.aws_region.region.name)
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in local.private_subnets : s.subnet_id] # Only attached to Private subnet as data subnet has access to communicate with private-subnet endpoint via 443
  security_group_ids  = [aws_security_group.endpoints.id]

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-privateca-endpoint", local.full_vpc_name)
      environment = var.environment
    }
  )
}

#########################################
# Interface Endpoint Security Group
#########################################
resource "aws_security_group" "endpoints" {
  provider    = aws.account
  name        = format("%s-vpc-endpoints", local.full_vpc_name)
  description = "Controls access to VPC Interface Endpoints"
  vpc_id      = aws_vpc.vpc.id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-vpc-endpoints", local.full_vpc_name)
      environment = var.environment
    }
  )
}

resource "aws_security_group_rule" "ingress_https" {
  provider          = aws.account
  type              = "ingress"
  description       = "inbound 443 from private subnets"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = flatten([[for s in local.private_subnets : s.cidr_block], [for s in local.data_subnets : s.cidr_block]])
  security_group_id = aws_security_group.endpoints.id
}


###############################################################################
# VPC FLOW LOGS
###############################################################################
resource "aws_iam_role" "vpc_flow_log_role" {
  provider           = aws.account
  name               = format("%s-%s-vpc-flow-log-role", data.aws_region.region.name, local.full_vpc_name)
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_log_assume.json
}

data "aws_iam_policy_document" "vpc_flow_log_assume" {
  provider = aws.account
  statement {
    sid     = "FlowLogTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "vpc_flow_log_policy" {
  provider = aws.account
  name     = format("%s-vpc-flow-log-policy", local.full_vpc_name)
  role     = aws_iam_role.vpc_flow_log_role.id
  policy   = data.aws_iam_policy_document.vpc_flow_log_policy.json
}

data "aws_iam_policy_document" "vpc_flow_log_policy" {
  provider = aws.account
  statement {
    sid       = "AllowCreateLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
    resources = ["*"]
  }
}

resource "aws_flow_log" "vpc_flow_log" {
  provider        = aws.account
  log_destination = aws_cloudwatch_log_group.flow_log_group.arn
  iam_role_arn    = aws_iam_role.vpc_flow_log_role.arn
  vpc_id          = aws_vpc.vpc.id
  traffic_type    = "ALL"
  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}

resource "aws_cloudwatch_log_group" "flow_log_group" {
  provider          = aws.account
  name              = format("/aws/vpc-flow-logs/%s", local.full_vpc_name)
  retention_in_days = 30
  kms_key_id        = data.aws_kms_key.logs.arn
  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}