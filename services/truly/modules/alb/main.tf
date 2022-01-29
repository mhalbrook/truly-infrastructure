################################################################################
# locals
################################################################################
#############################################################
# Global Locals
#############################################################
locals {
  load_balancer_type_abbreviation = var.load_balancer_type == "application" ? "alb" : "nlb"                                                                   # set shorthand of load balancer for naming convention
  full_load_balancer_name         = join("-", distinct(split("-", format("%s-%s-%s", var.project, var.service_name, local.load_balancer_type_abbreviation)))) # set load balancer name per volly standard schema, use split and distinct to remove any duplicate terms in name
  full_accelerator_name           = join("-", distinct(split("-", format("%s-%s-alb-accelerator", var.project, var.service_name))))                           # set global accelerator name per volly standard schema, use split and distinct to remove any duplicate terms in name
  internal                        = var.subnet_layer == "public" ? false : true                                                                               # set default configuration for whether load balancer is internet-facing
}

#############################################################
# Load Balancer Locals
#############################################################
locals {
  encrypted_protocol = var.load_balancer_type == "application" ? "HTTPS" : "TLS" # set appropriate protocol for encrypted load balancers
  default_protocol   = var.load_balancer_type == "application" ? "HTTP" : "TCP"  # set appropriate protocol for unencrypted load balancers
}

#############################################################
# Certificate Locals
#############################################################
locals {
  certificate_map = try(zipmap(                                                                                                                       # build map where Key is each Cretificate ARN specified in Listeners Variable and value is the coresponding listener, allowing certificates to easily be attached to specific listeners
    flatten([for v in local.listeners : v.certificate_arns]),                                                                                     # build list of certificate arns from listeners variable
    flatten([for k, v in local.listeners : [for i in range(length(v.certificate_arns)) : trimsuffix(format("%s%02d", k, i), format("%02d", i))]]) # build list of listeners where the listener name is repeated for each coresponding certificate. (i.e. if there are 3 certificates, the listener will be repeted 3 times within the list)
  ), null)
}

#############################################################
# Target Group Locals
#############################################################
locals {
  default_target_group   = element(keys(var.target_groups), 0)                                                                                                                                                                                                                                                                    # set default target group to the first target group listed in target groups variable
  full_target_group_name = { for k, v in var.target_groups : k => length(join("-", distinct(split("-", format("%s-%s-%s", var.project, var.service_name, k))))) < 32 ? join("-", distinct(split("-", format("%s-%s-%s", var.project, var.service_name, k)))) : join("-", distinct(split("-", format("%s-%s", var.project, k)))) } # Set map of full target name using Split and Distinct to deduplicate terms. If name is < 32 characters, drop service variable due to name length limitation.
}

#############################################################
# Listener Locals
#############################################################
locals {
  listeners = var.load_balancer_type == "application" && var.certificate_arns != null ? { # set default listener configuration for application load balancers using 443, otherwise, allow root to pass listener configurations
    443 = {
      target_group_name = local.default_target_group
      protocol          = "HTTPS"
      certificate_arns  = var.certificate_arns 
    }
    } : {
    for k, v in var.listeners :
    k => {
      target_group_name = v.target_group_name
      protocol          = aws_lb_target_group.targets[v.target_group_name].protocol
      certificate_arns  = try(v.certificate_arns, null)
    }
  }
}

#############################################################
# Static IP Locals
#############################################################
locals {
  static_ips = var.enable_static_ips == true && local.internal == false ? true : false # overwrite static IP setting when load balancer is internal as static IPs cannot be attached to internal load balancers
}


################################################################################
# Load Balancer
################################################################################
resource "aws_lb" "load_balancer" {
  provider                         = aws.account
  name                             = local.full_load_balancer_name
  load_balancer_type               = var.load_balancer_type
  internal                         = local.internal
  security_groups                  = var.load_balancer_type == "application" ? [aws_security_group.security_group[0].id] : null               # attach security group for Application Load Balancers only as Security Groups are not supported for Network load Balancers
  subnets                          = local.static_ips == true && var.load_balancer_type == "network" ? null : data.aws_subnet_ids.subnets.ids # if network load balancer with static IPs, do not set subnets as that is handled by the Subnet Mapping block
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  enable_http2                     = var.enable_http2
  enable_deletion_protection       = var.enable_deletion_protection
  ip_address_type                  = var.ip_address_type

  access_logs {
    bucket  = data.aws_s3_bucket.account_logging_bucket.id
    prefix  = local.full_load_balancer_name
    enabled = true
  }

  dynamic "subnet_mapping" { # set static IP addresses for network load balancers (applicaiton load balancer static IPs are provided via Global Accelerator)
    for_each = local.static_ips == true && var.load_balancer_type == "network" ? { for v in data.aws_subnet.subnet : v.tags.Name => v.id } : {}
    content {
      subnet_id     = subnet_mapping.value
      allocation_id = aws_eip.eip[subnet_mapping.key].id
    }
  }

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
      Name        = local.full_load_balancer_name
    }
  )
}


################################################################################
# Load Balancer Listeners
################################################################################
resource "aws_lb_listener" "http" {
  provider          = aws.account
  count             = var.load_balancer_type == "application" && local.internal == false && var.listeners == null ? 1 : 0
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = var.http_port
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = element(keys(local.listeners), 0) # redirect to the first listener listed, in most cases this will be a 443 listener
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "listener" {
  provider          = aws.account
  for_each          = local.listeners
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = each.key
  protocol          = length(each.value.certificate_arns) > 0 ? local.encrypted_protocol : local.default_protocol # if certificates are provided, set protocol to 'TLS' or "HTTPS'
  certificate_arn   = length(each.value.certificate_arns) > 0 ? element(each.value.certificate_arns, 0) : null    # if certificates are not provided, set to null
  ssl_policy        = length(each.value.certificate_arns) > 0 ? "ELBSecurityPolicy-TLS-1-2-2017-01" : null        # if certificates are provided, set up-to-date ssl policy

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targets[each.value.target_group_name].arn
  }
}


#############################################################
# Listener Certificates
#############################################################
resource "aws_lb_listener_certificate" "certificate" {
  provider        = aws.account
  for_each        = local.certificate_map #{ for k, v in local.certificate_map : k => v if k != aws_lb_listener.listener[v].certificate_arn } # Attach certificates that are not already attached to the listeners as default certificates
  listener_arn    = aws_lb_listener.listener[each.value].arn
  certificate_arn = each.key

  depends_on = [aws_lb_listener.listener]
}

#############################################################
# Listener Rules
#############################################################
resource "aws_lb_listener_rule" "listener_rule" {
  provider     = aws.account
  for_each     = var.load_balancer_type == "application" ? var.listener_rules : {}
  listener_arn = length(local.listeners) > 1 ? aws_lb_listener.listener[each.value.listener_port].arn : aws_lb_listener.listener[element(keys(local.listeners), 0)].arn # if only one listener is created, set to that listener's ARN, otherwise allow listener ARNs to be passed vrom the listener rule variable            
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targets[each.value.target_group_name].arn
  }

  dynamic "condition" {
    for_each = each.value.host_header
    content {
      host_header {
        values = each.value.host_header
      }
    }
  }

  dynamic "condition" {
    for_each = each.value.path_pattern
    content {
      path_pattern {
        values = each.value.path_pattern
      }
    }
  }

  dynamic "condition" {
    for_each = each.value.http_header
    content {
      http_header {
        http_header_name = condition.key
        values           = condition.value
      }
    }
  }
}

################################################################################
# Target groups
################################################################################
resource "aws_lb_target_group" "targets" {
  provider                      = aws.account
  for_each                      = var.target_groups
  name                          = element([for k, v in local.full_target_group_name : v if k == each.key], 0)
  vpc_id                        = var.vpc_id
  port                          = each.value.port
  protocol                      = upper(each.value.protocol)
  target_type                   = each.value.type
  deregistration_delay          = var.deregistration_delay
  load_balancing_algorithm_type = var.load_balancer_type == "application" ? var.load_balancing_algorithm : null # set algorithm type for Application laod Balancers only, as algorithms are not supported for Network load Balancers

  health_check {
    path                = var.load_balancer_type == "application" ? each.value.health_check_path : null # set heathcheck path for Application laod Balancers only, as paths are not supported for Network load Balancers
    protocol            = each.value.health_check_protocol
    healthy_threshold   = var.health_check_healthy_threshold
    timeout             = var.load_balancer_type == "application" ? var.health_check_timeout : null # do not set for TLS Protocol as custom timeouts are not supported
    unhealthy_threshold = var.health_check_unhealthy_threshold
    interval            = var.health_check_interval
    matcher             = var.load_balancer_type == "application" ? var.health_check_matcher : null # set heathcheck matcher for Application laod Balancers only, as paths are not supported for Network load Balancers
    port                = each.value.port
  }

  dynamic "stickiness" {
    for_each = var.sticky_session_duration != null ? [var.sticky_session_duration] : []
    content {
      enabled         = true
      type            = "lb_cookie"
      cookie_duration = var.sticky_session_duration
    }
  }

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}


################################################################################
# Security Groups
################################################################################
resource "aws_security_group" "security_group" {
  provider    = aws.account
  count       = var.load_balancer_type == "application" ? 1 : 0
  name        = local.full_load_balancer_name
  description = "Controls access to the Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = local.full_load_balancer_name
      environment = var.environment
    }
  )
}

#############################################################
# Security Group Rules
#############################################################
resource "aws_security_group_rule" "ingress" {
  provider          = aws.account
  for_each          = var.load_balancer_type == "application" ? toset(concat([80], keys(local.listeners))) : []
  type              = "ingress"
  description       = "inbound traffic to the Load Balancer listener"
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.security_group[0].id
}


################################################################################
# Elastic IPs (Static IPs for Network Load Balancers)
################################################################################
resource "aws_eip" "eip" {
  provider = aws.account
  for_each = local.static_ips == true && var.load_balancer_type == "network" ? { for v in data.aws_subnet.subnet : v.tags.Name => v.id } : {}
  vpc      = true
  tags = merge(
    var.tags,
    var.default_tags,
    {
      Name        = format("%s-%s", local.full_load_balancer_name, each.key)
      environment = var.environment
    }
  )
}

################################################################################
# Global Accelerator (Static IPs for Applicaiton Load Balancers)
################################################################################
resource "aws_globalaccelerator_accelerator" "accelerator" {
  provider        = aws.account
  count           = local.static_ips == true && var.load_balancer_type == "application" ? 1 : 0
  name            = local.full_accelerator_name
  ip_address_type = "IPV4"
  enabled         = true

  attributes {
    flow_logs_enabled   = true
    flow_logs_s3_bucket = data.aws_s3_bucket.account_logging_bucket.id
    flow_logs_s3_prefix = format("%s/accelerator", local.full_load_balancer_name)
  }
}

resource "aws_globalaccelerator_listener" "listener" {
  provider        = aws.account
  count           = local.static_ips == true && var.load_balancer_type == "application" ? 1 : 0
  accelerator_arn = aws_globalaccelerator_accelerator.accelerator[0].id
  client_affinity = "SOURCE_IP"
  protocol        = "TCP"

  dynamic "port_range" {
    for_each = concat([80], keys(local.listeners)) # create a port mapping for each listener port, include 80 for http (mappings are only for applicaiton load balancers)
    content {
      from_port = port_range.value
      to_port   = port_range.value
    }
  }
}

resource "aws_globalaccelerator_endpoint_group" "endpoint_group" {
  provider     = aws.account
  count        = local.static_ips == true && var.load_balancer_type == "application" ? 1 : 0
  listener_arn = aws_globalaccelerator_listener.listener[0].id

  endpoint_configuration {
    endpoint_id                    = aws_lb.load_balancer.arn
    weight                         = 100
    client_ip_preservation_enabled = true
  }
}


################################################################################
# Service Discovery
################################################################################
resource "aws_service_discovery_service" "service" {
  provider      = aws.account
  count         = var.namespace_id != null ? 1 : 0
  name          = var.service_discovery_name
  force_destroy = true

  dns_config {
    namespace_id   = var.namespace_id
    routing_policy = "WEIGHTED"

    dns_records {
      ttl  = 300
      type = "A"
    }
  }

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}

resource "aws_service_discovery_instance" "instance" {
  provider    = aws.account
  count       = var.namespace_id != null ? 1 : 0
  instance_id = var.service_discovery_name
  service_id  = aws_service_discovery_service.service[0].id

  attributes = {
    AWS_ALIAS_DNS_NAME = aws_lb.load_balancer.dns_name
  }
}