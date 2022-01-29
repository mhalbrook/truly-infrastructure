################################################################################
# Locals
################################################################################
#############################################################
# Hosted Zone Locals
#############################################################
locals {
  apex_domain = var.apex_domain == null ? join(".", slice(split(".", var.record_name), length(split(".", var.record_name)) - 2, length(split(".", var.record_name)))) : var.apex_domain # if apex domain is not provided, use the root of the Provided record name for validation (i.e. one.example.com becomes example.com)
}

#############################################################
# Record Locals
#############################################################
locals {
  record_count  = var.routing_policy != "simple" ? 2 : 1 # if route type is simple, generate one record, otherwise create 2 records (i.e. multivalue, failover or latency routing)
  record_values = flatten([var.record_values])           # flatten record values to handle argument where multiple lists of record values are provided
  ttl           = var.alias == true ? null : var.ttl     # only set TTL if the record type is not 'alias'
}

#############################################################
# Health Check Locals
#############################################################
locals {
  health_check      = local.record_count > 1 ? true : var.health_check                           # if a multivalue record is created, enable health check, otherwise allow heathcheck to be enabled/disabled via variable
  default_port      = var.health_check_protocol == "HTTP" ? "80" : "443"                         # set the health check port based on the health check protocol
  health_check_port = var.health_check_port == null ? local.default_port : var.health_check_port # allow health check port variable to override default ports
}


################################################################################
# Route 53 Record
################################################################################
resource "aws_route53_record" "record" {
  provider                         = aws.account
  count                            = local.record_count
  zone_id                          = data.aws_route53_zone.apex_zone.zone_id
  name                             = var.record_name
  type                             = var.record_type
  ttl                              = local.ttl
  multivalue_answer_routing_policy = var.routing_policy == "multivalue" ? true : null
  records                          = var.alias == true ? null : var.record_type == "NS" ? local.record_values : [element(local.record_values, count.index)] # if record is an alias, set to null. if the record type is NS, set the value to the entire record value list, otherwise set value to each record value per index
  set_identifier                   = var.routing_policy == "simple" ? null : format("%s-record-%s", var.routing_policy, count.index + 1)
  health_check_id                  = local.health_check == false ? null : element(aws_route53_health_check.health_check.*.id, count.index)

  dynamic "alias" {
    for_each = var.alias == true ? ["alias"] : []
    content {
      name                   = var.alias == true ? element(local.record_values, count.index) : null
      zone_id                = var.zone_id
      evaluate_target_health = var.health_check
    }
  }

  dynamic "failover_routing_policy" {
    for_each = var.routing_policy == "failover" ? ["failover"] : []
    content {
      type = element(["PRIMARY", "SECONDARY"], count.index)
    }
  }

  dynamic "latency_routing_policy" {
    for_each = var.routing_policy == "latency" ? ["latency"] : []
    content {
      region = element(var.region, count.index)
    }
  }

  dynamic "weighted_routing_policy" {
    for_each = var.routing_policy == "weighted" ? ["weighted"] : []
    content {
      weight = element([var.weight, var.weight - 100], count.index)
    }
  }
}

################################################################################
# Health Checks
################################################################################
resource "aws_route53_health_check" "health_check" {
  provider          = aws.account
  count             = local.health_check == true ? local.record_count : 0
  reference_name    = format("%s-record-%s", var.routing_policy, count.index + 1)
  fqdn              = var.record_name
  ip_address        = var.record_type == "A" && var.alias == false ? element(local.record_values, count.index) : null
  type              = var.health_check_protocol
  port              = local.health_check_port
  failure_threshold = var.health_check_threshold
  request_interval  = var.health_check_interval
  resource_path     = var.health_check_path

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}