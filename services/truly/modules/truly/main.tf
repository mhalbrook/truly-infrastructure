################################################################################
# Locals
################################################################################
#############################################################
# Global Locals
#############################################################
locals {
  full_fargate_name = format("%s-%s", var.project, var.service_name) # set naming conventions to align to Volly standard schema
}

#############################################################
# Network Locals
#############################################################
locals {
  private_subnet_cidrs = [for s in data.aws_subnet.private : s.cidr_block]                                                       # get cidr blocks of subnets in which to provision the Fargate Tasks
  discovery_name       = local.application_container == true ? var.service_name : format("%s-%s", var.project, var.service_name) # If and Application container is being created, set the Service Discovery name for AWS CloudMap to the service name, otherwise set to project name - service name.
}

#############################################################
# Secrets & Parameter Locals
#############################################################
locals {
  secrets               = length(var.parameters) == 0 ? "null" : jsonencode(concat([for k, v in var.parameters : { "name" : element(split("/", k), length(split("/", k)) - 1), "valueFrom" : v }]))                                                     # if parameters variable is set, create map of secrets using last value in the variable key (parameter name) and the variable value. Used to pass secrets to each Container Definition.
  environment_variables = var.environment_variables == {} ? jsonencode(concat([{ "name" : "APP_PORT", "value" : tostring(var.app_port) }])) : jsonencode(concat([{ "name" : "APP_PORT", "value" : tostring(var.app_port) }], [for k, v in var.environment_variables : { "name" : element(split("/", k), length(split("/", k)) - 1), "valueFrom" : v }])) # if environment variable is not set, create a map of just the required app port, otherwise merge the map of app port with a map of provided environment variables. Environment variables are then passes to each Container Definition.
}

#############################################################
# Container  Locals
#############################################################
locals {
  container_name        = local.application_container == true ? local.full_fargate_name : "envoy"
  application_container = var.image != null ? true : false                                                     # Determine if an application container needs to be deployed (i.e. application container is not required for Virtual Gateways)
  envoy_container       = var.app_mesh_virtual_node != null ? true : false                                     # Determine if Envoy Sidecar is required
  xray_container        = var.app_mesh_virtual_node != null ? true : false                                     # Determine if X-ray Sidecar is required
  gateway_container     = local.envoy_container == true && local.application_container == false ? true : false # Determine if container is an App Mesh Virtual Gateway 
}

###################################
# Container Image Locals
###################################
locals {
  ecr_repository    = format("%s.dkr.ecr.%s.amazonaws.com", data.aws_caller_identity.cicd.account_id, data.aws_region.region.name)                                                                      # Set the default ECR repository used to store container images
  image             = local.application_container == true ? var.image : ""                                                                                                                              # if image variable is null set to empty string to allow application image local to successfully execute replace function
  application_image = replace(local.image, "amazonaws.com", "") != local.image ? format("%s:%s", local.image, var.environment) : format("%s/%s:%s", local.ecr_repository, local.image, var.environment) # if image variable is not the full repository path, use default repository. Allows root module to pass friendly image name.
  envoy_image       = format("%s:%s", var.envoy_image, var.envoy_image_version)                                                                                                                         # Set the image for the Envoy sidecar containers
  xray_image        = format("%s:%s", var.xray_image, var.xray_image_version)
}

###################################
# Autoscaling Locals
###################################
locals {
  autoscaling  = local.max_capacity > var.desired_capacity ? true : false           # Set whether autoscaling should be enabled. Set to 'true' when max capacity is greater than desired capacity.
  max_capacity = var.max_capacity == null ? var.desired_capacity : var.max_capacity # if max capacity is not provided, set max capacity equal to desired capacity. This disables Autoscaling for the Fargate service.
  autoscaling_policy_configuration = merge(
    { for k, v in local.autoscaling_cpu_policy : k => v if length(v) > 0 },           # Merge map of custom or default cpu policy. If cpu policy is set to {}, do not merge cpu policy.
    { for k, v in local.autoscaling_memory_policy : k => v if length(v) > 0 },        # Merge map of custom or default memory policy. If memory policy is set to {}, do not merge memory policy.
    { for k, v in local.autoscaling_load_balancing_policy : k => v if length(v) > 0 } # Merge map of custom load balancing policy. If custom load balancing policy is not provided, do not merge Load Balancing policy.
  )
  autoscaling_cpu_policy = var.autoscaling_cpu_policy != null ? { ECSServiceAverageCPUUtilization = var.autoscaling_cpu_policy } : { # Set to custom cpu policy if provided, otherwise use default cpu policy.
    ECSServiceAverageCPUUtilization = {
      target_value       = 65
      scale_in_cooldown  = 300
      scale_out_cooldown = 300
    }
  }
  autoscaling_memory_policy = var.autoscaling_memory_policy != null ? { ECSServiceAverageMemoryUtilization = var.autoscaling_memory_policy } : { # Set to custom memory policy if provided, otherwise use default memory policy.
    ECSServiceAverageMemoryUtilization = {
      target_value       = 80
      scale_in_cooldown  = 300
      scale_out_cooldown = 300
    }
  }
  autoscaling_load_balancing_policy = var.autoscaling_load_balancing_policy != null ? { ALBRequestCountPerTarget = var.autoscaling_load_balancing_policy } : {} # Set to custom load balancing policy if provided, otherwise do not create a load balancing policy.
}

###################################
# Container Memory Limit Locals
###################################
locals {
  application_memory_hard_limit = local.application_container == true ? (var.container_memory - local.envoy_memory_soft_limit) - local.xray_memory_soft_limit : 0 # set the max amount of memory the Application Container may use before crashing the ECS Task
  application_memory_soft_limit = local.application_container == true ? var.container_memory / 2 : 0                                                              # set the amount of memory to be reserved for the Application Container
  envoy_memory_hard_limit       = local.envoy_container == true ? 500 : 0                                                                                         # set the max amount of memory the Envoy Sidecar may use before crashing the ECS Task
  envoy_memory_soft_limit       = local.envoy_container == true ? local.envoy_memory_hard_limit - 200 : 0                                                         # set the amount of memory to be reserved for the Envoy Sidecar
  gateway_memory_hard_limit     = local.gateway_container == true ? var.container_memory - local.envoy_memory_soft_limit - local.xray_memory_soft_limit : 0       # set the max amount of memory the Envoy Virtual Gateway may use before crashing the ECS Task
  gateway_memory_soft_limit     = local.gateway_container == true ? var.container_memory / 2 : 0                                                                  # set the amount of memory to be reserved for the Envoy Virtual Gateway
  xray_memory_hard_limit        = local.xray_container == true ? 256 : 0                                                                                          # set the max amount of memory the X-ray Sidecar may use before crashing the ECS Task
  xray_memory_soft_limit        = local.xray_container == true ? local.xray_memory_hard_limit - 100 : 0                                                           # set the amount of memory to be reserved for the X-ray Sidecar                                               
}


###################################
# Container Allocation Locals
###################################
locals {
  application_cpu_units = local.application_container == true ? (var.container_cpu_units - local.envoy_cpu_units) - local.xray_cpu_units : 0 # If application container is deployed, allocate all CPU units not allocated to sidecar containers
  envoy_cpu_units       = 0                                                                                                                  # Envoy sidecars share CPU units with the running application container, therefore CPU units should never be allocated 
  gateway_cpu_units     = local.gateway_container == true ? var.container_cpu_units - local.xray_cpu_units : 0                               # If Envoy Sidecar is a Virtual Gateway, allocate all CPU to Envoy, except CPU Units allocated to X-Ray sidecar
  xray_cpu_units        = local.xray_container == true ? 32 : 0                                                                              # if X-Ray sidecar is deployed, allocate 32 CPU units to X-Ray                                                                                                                             
}

###################################
# Container Definition Locals
###################################
locals {
  container_definitions = { for k, v in local.container_definition_arguments : k => v if v.active == true } # Build map of Container Definitions that are required using the below configuration settings
  container_definition_arguments = {                                                                        # Set configuration for various containers in the ECS Task
    application = {
      active                = local.application_container
      container_name        = local.full_fargate_name
      image                 = local.application_image
      cpu_units             = local.application_cpu_units # If using X-Ray sidecar, reserve 32 cpu units for sidecar, otherwise use all units for app container
      memory                = local.application_memory_hard_limit
      memory_reservation    = local.application_memory_soft_limit
      essential             = true # Ensure Fargate service stops if app container becomes unhealthy
      secrets               = local.secrets
      depends_on            = var.app_mesh_virtual_node != null ? jsonencode([{ "containerName" : "envoy", "condition" : "HEALTHY" }]) : "null" # If using App Mesh, make app container dependent on a Healthy envoy sidecar
      mount_points          = var.efs_file_system_name != null ? jsonencode([{ "containerPath" : var.efs_container_path, "sourceVolume" : var.efs_source_volume }]) : "[]"                                       # If attaching an EFS volume, set mount points
      port_mappings         = jsonencode([{ "hostPort" : var.app_port, "protocol" : "tcp", "containerPort" : var.app_port }])                                                                                    # Set port mappings to app port
      ulimits               = "null"
      healthcheck           = "null"
      user                  = "null"
      command               = var.entry_point != null ? format("[\"%s\"]", var.entry_point) : "null"
      volumes_from          = "[]"
      docker_labels         = "null"
      environment_variables = local.environment_variables
    }
    envoy = {
      active             = local.envoy_container
      container_name     = "envoy"
      image              = local.envoy_image                                                                                 # Set the tag of the Envoy container (determines envoy version)
      cpu_units          = local.gateway_container == true ? local.gateway_cpu_units : local.envoy_cpu_units                 # Envoy shares cpu units with app container and, therefore, requires 0 cpu units
      memory             = local.gateway_container == true ? local.gateway_memory_hard_limit : local.envoy_memory_hard_limit # if Envoy container is a Virtual Gateway, allow envoy to use all available memory, otherwise restrict use
      memory_reservation = local.gateway_container == true ? local.gateway_memory_soft_limit : local.envoy_memory_soft_limit # if Envoy container is a Virtual Gateway, reserve all memory for envoy, otherwise restrict reservation
      essential          = true                                                                                              # Ensure Fargate service stops if envoy container becomes unhealthy
      secrets            = "null"
      depends_on         = "null"
      mount_points       = "[]"
      port_mappings      = local.gateway_container == true ? jsonencode([{ "hostPort" : var.app_port, "protocol" : "tcp", "containerPort" : var.app_port }]) : "[]" # if Envoy container is a Virtual Gateway, set port mappings, otherwise port mappings are not required
      ulimits            = local.gateway_container == true ? jsonencode([{ "hardLimit" : 15000, "name" : "nofile", "softLimit" : 15000 }]) : "null"                 # if Envoy container is a Virtual Gateway, set ulimits, otherwise ulimits are not required
      healthcheck        = jsonencode({ "command" : ["CMD-SHELL", "curl -s http://localhost:9901/server_info | grep state | grep -q LIVE"], "interval" : 10, "timeout" : 5, "startPeriod" : 30, "retries" : 3 })
      user               = "\"1337\""
      command            = "null"
      volumes_from       = "[]"
      docker_labels      = "null"
      environment_variables = jsonencode([
        { "name" : "APPMESH_VIRTUAL_NODE_NAME", "value" : var.app_mesh_virtual_node },
        { "name" : "ENVOY_LOG_LEVEL", "value" : var.envoy_log_level },
      { "name" : "ENABLE_ENVOY_XRAY_TRACING", "value" : "1" }])
    }
    xray = {
      active                = local.xray_container
      container_name        = "xray-daemon"
      image                 = local.xray_image
      cpu_units             = local.xray_cpu_units         # reserve 32 cpu units for X-Ray sidecar
      memory                = local.xray_memory_hard_limit # Set max amount of memory the X-Ray sidecar may utilize
      memory_reservation    = local.xray_memory_soft_limit # Set amount of memory to reserve for the X-Ray sidecar
      essential             = false                        # Ensure that Fargate Service does NOT stop if X-Ray container becomes unhealthy
      secrets               = "null"
      depends_on            = "null"
      mount_points          = "[]"
      port_mappings         = jsonencode([{ "protocol" : "udp", "containerPort" : 2000, "hostPort" : 2000 }])
      ulimits               = "null"
      healthcheck           = "null" # X-ray sidecar does not support running shell commands from the container, therefore, internal health checks are not possible
      user                  = "\"1337\""
      command               = "null"
      volumes_from          = "[]"
      docker_labels         = "null"
      environment_variables = "null"
    }
  }
}


################################################################################
# ECS Service
################################################################################
resource "aws_ecs_service" "fargate_service" {
  provider                           = aws.account
  name                               = local.full_fargate_name
  cluster                            = var.cluster_id
  platform_version                   = "1.4.0"
  launch_type                        = "FARGATE"
  task_definition                    = aws_ecs_task_definition.fargate_task.arn
  desired_count                      = var.desired_capacity
  deployment_maximum_percent         = var.desired_capacity > 3 ? 125 : var.desired_capacity < 2 ? 200 : 150 # Set appropriate deployment velocity based on number of containers. This determines how quickly deployments occur. Fast deployments may result in instability.
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds  = var.load_balancer_arn != null ? var.health_check_grace_period : 0 # If task is connected to a load balancer, set period to wait for the container to become stable before being evaluated by the load balancer. Ensures the load balancer does not stops tasks prematurely. 
  force_new_deployment               = var.force_new_deployment                                          # Allows the module to force a deployment of the Fargate service when Task Definitions are updated.
  enable_execute_command             = true

  network_configuration {
    subnets         = data.aws_subnet_ids.private.ids
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  dynamic "load_balancer" {
    for_each = var.load_balancer_arn != null ? ["load_balancer"] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = local.container_name
      container_port   = var.app_port
    }
  }

  dynamic "service_registries" {
    for_each = var.namespace_id != null ? [var.namespace_id] : []
    content {
      registry_arn   = aws_service_discovery_service.service[var.namespace_id].arn
      container_port = var.namespace_record_type == "A" ? null : var.app_port # if creating SRV records, supply the port, otherwise exclude the port
      container_name = local.container_name
    }
  }

  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  depends_on = [null_resource.lb_exists]
}

resource "null_resource" "lb_exists" { # Ensures the load balancer is in an active state before building the Fargate Service
  triggers = {
    lb_name = var.load_balancer_arn
  }
}


#############################################################
# Task Definition
#############################################################
resource "aws_ecs_task_definition" "fargate_task" {
  provider                 = aws.account
  execution_role_arn       = aws_iam_role.fargate_role["execution"].arn
  task_role_arn            = aws_iam_role.fargate_role["task"].arn
  family                   = local.full_fargate_name
  container_definitions    = data.template_file.container_definition.rendered
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu_units
  memory                   = var.container_memory
  network_mode             = "awsvpc"

  dynamic "proxy_configuration" { # If using App Mesh, but task is not a Virtual Gateway, set a proxy configuration
    for_each = local.gateway_container == false && local.envoy_container == true ? toset([var.app_mesh_virtual_node]) : []
    content {
      type           = "APPMESH"
      container_name = "envoy"
      properties = {
        AppPorts           = var.app_port
        EgressIgnoredIPs   = "169.254.170.2,169.254.169.254"
        EgressIgnoredPorts = ""
        IgnoredGID         = ""
        IgnoredUID         = "1337"
        ProxyEgressPort    = 15001
        ProxyIngressPort   = 15000
      }
    }
  }

  dynamic "volume" { # If attaching an EFS volume, set the EFS volume configuration
    for_each = var.efs_file_system_name != null ? [var.efs_file_system_name] : []
    content {
      name = upper(var.efs_file_system_name)
      efs_volume_configuration {
        file_system_id          = aws_efs_file_system.efs[0].id
        root_directory          = "/"
        transit_encryption      = "ENABLED"
        transit_encryption_port = null
        authorization_config {
          access_point_id = aws_efs_access_point.access_point[0].id
          iam             = "DISABLED"
        }
      }
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

#############################################################
# Container Definitions
#############################################################
data "template_file" "container_definition" { # combine container definitions created by the container_definition_segments block in order to generate a single definition of all containers required for the Task
  template = file(format("%s/templates/container_definition.tpl", path.module))
  vars = {
    container_definitions = trimsuffix(join("", [for d in data.template_file.container_definition_segments : d.rendered]), ",")
  }
}

data "template_file" "container_definition_segments" { # create a container definition for each container required for the Task
  for_each = local.container_definitions
  template = file(format("%s/templates/container_definition_segments.tpl", path.module))
  vars = {
    container_name        = each.value.container_name
    image                 = each.value.image
    essential             = each.value.essential
    cpu_units             = each.value.cpu_units
    memory                = each.value.memory
    memory_reservation    = each.value.memory_reservation
    aws_region            = data.aws_region.region.name
    awslogs_group         = aws_cloudwatch_log_group.fargate_log_group.name
    environment_variables = each.value.environment_variables
    secrets               = each.value.secrets
    depends_on            = each.value.depends_on
    mount_points          = each.value.mount_points
    port_mappings         = each.value.port_mappings
    ulimits               = each.value.ulimits
    healthcheck           = each.value.healthcheck
    user                  = each.value.user
    command               = each.value.command
    volumes_from          = each.value.volumes_from
    docker_labels         = each.value.docker_labels
  }
}

#############################################################
# AutoScaling
#############################################################
resource "aws_appautoscaling_target" "fargate" { # Enable autoscaling if max capacity is greater than desired capacity
  provider           = aws.account
  for_each           = local.max_capacity != var.desired_capacity ? toset([aws_ecs_service.fargate_service.name]) : []
  max_capacity       = local.max_capacity
  min_capacity       = var.desired_capacity
  resource_id        = format("service/%s/%s", var.cluster_name, each.value)
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  lifecycle {
    ignore_changes = [min_capacity]
  }
}

resource "aws_appautoscaling_policy" "ecs_policy" { # Create an Autoscaling policy for each metric requested (cpu, memory, and/or alb requests)
  provider           = aws.account
  for_each           = local.autoscaling == true ? local.autoscaling_policy_configuration : {}
  name               = format("%s-%s-autoscaling-policy", local.full_fargate_name, lower(each.key))
  policy_type        = var.autoscaling_type
  resource_id        = aws_appautoscaling_target.fargate[aws_ecs_service.fargate_service.name].resource_id
  scalable_dimension = aws_appautoscaling_target.fargate[aws_ecs_service.fargate_service.name].scalable_dimension
  service_namespace  = aws_appautoscaling_target.fargate[aws_ecs_service.fargate_service.name].service_namespace

  dynamic "target_tracking_scaling_policy_configuration" { # Set policy configuration for TargetTracking Autoscaling policies
    for_each = var.autoscaling_type == "TargetTrackingScaling" ? { for k, v in local.autoscaling_policy_configuration : k => v if k == each.key } : {}
    content {
      target_value       = target_tracking_scaling_policy_configuration.value.target_value
      scale_in_cooldown  = target_tracking_scaling_policy_configuration.value.scale_in_cooldown
      scale_out_cooldown = target_tracking_scaling_policy_configuration.value.scale_out_cooldown
      disable_scale_in   = false

      dynamic "predefined_metric_specification" { # Set as dynamic block to ensure Customized Metric Specifications support may be added in the future if required.
        for_each = { for k, v in local.autoscaling_policy_configuration : k => v if k == each.key }
        content {
          predefined_metric_type = predefined_metric_specification.key
        }
      }
    }
  }
}


################################################################################
# Cloudwatch Log Group
################################################################################
resource "aws_cloudwatch_log_group" "fargate_log_group" {
  provider          = aws.account
  name              = format("/volly/%s", local.full_fargate_name)
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


################################################################################
# Security Group
################################################################################
resource "aws_security_group" "ecs_tasks" {
  provider               = aws.account
  name                   = format("%s-task", local.full_fargate_name)
  description            = "allow inbound access from the ALB only"
  vpc_id                 = data.aws_vpc.vpc.id
  revoke_rules_on_delete = true

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
      Name        = format("%s-task", local.full_fargate_name)
    }
  )
}

#############################################################
# Security Group Rules
#############################################################
resource "aws_security_group_rule" "task_ingress_lb" {
  provider                 = aws.account
  count                    = var.load_balancer_type == "application" ? 1 : 0
  type                     = "ingress"
  description              = "inbound traffic from LB on app port"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = var.load_balancer_security_group
  security_group_id        = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "task_ingress_app" {
  provider                 = aws.account
  for_each                 = toset(var.inbound_access)
  type                     = "ingress"
  description              = "inbound traffic from other services on app port"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  prefix_list_ids          = trimprefix(each.value, "pl-") != each.value ? [each.value] : null                                                # if the value provided in the inbound_access variable is a Prefix List (begins with 'pl-') then set prefix list as source
  source_security_group_id = trimprefix(each.value, "sg-") != each.value ? each.value : null                                                  # if the value provided in the inbound_access variable is a Security Group (begins with 'sg-') then set Security Group as source
  cidr_blocks              = trimprefix(each.value, "pl-") == each.value && trimprefix(each.value, "sg-") == each.value ? [each.value] : null # if value provided is not a Prefix List OR a Security Group, set CIDR Block as source
  security_group_id        = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "task_egress_nfs" {
  provider                 = aws.account
  count                    = var.efs_file_system_name != null ? 1 : 0
  type                     = "egress"
  description              = "outbound NFS connections to EFS Mount Point"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.mount_target[0].id
  security_group_id        = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "task_egress_https" {
  provider          = aws.account
  type              = "egress"
  description       = "outbound https to internet"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_tasks.id
}

resource "aws_security_group_rule" "task_egress_http" {
  provider          = aws.account
  type              = "egress"
  description       = "outbound http to internet"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_tasks.id
}


resource "aws_security_group_rule" "task_egress_app" {
  provider                 = aws.account
  for_each                 = var.outbound_access
  type                     = "egress"
  description              = "outbound communication to other services"
  from_port                = each.value
  to_port                  = each.value
  protocol                 = "tcp"
  prefix_list_ids          = trimprefix(each.key, "pl-") != each.key ? [each.key] : null                                            # if the value provided in the inbound_access variable is a Prefix List (begins with 'pl-') then set prefix list as destination
  source_security_group_id = trimprefix(each.key, "sg-") != each.key ? each.key : null                                              # if the value provided in the inbound_access variable is a Security Group (begins with 'sg-') then set Security Group as destination
  cidr_blocks              = trimprefix(each.key, "pl-") == each.key && trimprefix(each.key, "sg-") == each.key ? [each.key] : null # if value provided is not a Prefix List OR a Security Group, set CIDR Block as destination
  security_group_id        = aws_security_group.ecs_tasks.id
}

#############################################################
# Load Balancer Security Group Rule
#############################################################
resource "aws_security_group_rule" "alb_egress_task" {
  provider                 = aws.account
  count                    = var.load_balancer_type == "application" ? 1 : 0
  type                     = "egress"
  description              = format("outbound traffic to %s", var.service_name)
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = var.load_balancer_security_group
}


################################################################################
# IAM Roles
################################################################################
resource "aws_iam_role" "fargate_role" { # Create IAM role used by Fargate to launch Tasks
  provider           = aws.account
  for_each           = toset(["execution", "task"])
  name               = format("%s-fargate-%s", local.full_fargate_name, each.value)
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
    }
  )
}


#############################################################
# IAM Policies
#############################################################
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "app_mesh_policy" { # Enables retrieval of App Mesh configuration and encryption certificates
  statement {
    sid       = "AppMeshConfig"
    effect    = "Allow"
    actions   = ["appmesh:StreamAggregatedResources"]
    resources = ["arn:aws:appmesh:*:*:mesh/*"]
  }
  statement {
    sid       = "ExportCert"
    effect    = "Allow"
    actions   = ["acm:ExportCertificate"]
    resources = ["arn:aws:acm:*:*:certificate/*"]
  }
  statement {
    sid       = "GetCertificateAuthorityCertificate"
    effect    = "Allow"
    actions   = ["acm-pca:GetCertificateAuthorityCertificate"]
    resources = ["arn:aws:acm-pca:*:*:certificate-authority/*"]
  }
}

data "aws_iam_policy_document" "ssm_access_policy" { # enables retrieval of values from Parameter Store and/or Secrets Manager based on tag conditions
  count = length(var.parameters) > 0 ? 1 : 0
  statement {
    sid       = "SSMAccess"
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:*:*:parameter/*"]
    condition {
      test     = "ForAnyValue:StringLike"
      variable = "ssm:ResourceTag/service"
      values = [ # only allow access to parameters where the 'service' tag matches the name of the service or 'global'
        "global",
        var.service_name
      ]
    }
  }
  statement {
    sid       = "KMSAccess"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "ForAnyValue:StringLike"
      variable = "aws:ResourceTag/aws_service"
      values   = ["parameter_store", "secrets_manager"]
    }
  }
  statement {
    sid       = "SecretManagerAccess"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:*:*:secret:*"]
    condition {
      test     = "ForAnyValue:StringLike"
      variable = "secretsmanager:ResourceTag/service"
      values = [ # only allow access to secrets where the 'service' tag matches the name of the service or 'global'
        "global",
        var.service_name
      ]
    }
  }
}

data "aws_iam_policy_document" "ecs_exec_policy" { # Enables sending remote commands to containers via AWS CLI
  statement {
    sid       = "ECSExec"
    effect    = "Allow"
    actions   = ["ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]
    resources = ["*"]
  }
  statement {
    sid       = "DescribeLogGroups"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }
  statement {
    sid       = "CreateLogStreams"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"]
    resources = [format("arn:aws:logs:%s:%s:log-group:/volly/%s/ecs-exec:*", data.aws_region.region.name, data.aws_caller_identity.account.account_id, var.cluster_name)]
  }
  statement {
    sid       = "AccessSSMKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_key.session_manager.arn]
  }
}

resource "aws_iam_policy" "app_mesh_policy" { # If Task uses Envoy sidecar, create App Mesh policy
  provider    = aws.account
  count       = local.envoy_container == true ? 1 : 0
  name        = format("%s-appmesh", local.full_fargate_name)
  description = format("Allows %s to download app mesh configuration", local.full_fargate_name)
  policy      = data.aws_iam_policy_document.app_mesh_policy.json
}

resource "aws_iam_policy" "ssm_policy" { # If Environment Variables are provided to teh module, create Environment Variable policy
  provider    = aws.account
  count       = length(var.parameters) > 0 ? 1 : 0
  name        = format("%s-environmentvariables", local.full_fargate_name)
  description = format("Allows %s to access parameters and secrets to set Environment Variables", local.full_fargate_name)
  policy      = data.aws_iam_policy_document.ssm_access_policy[0].json
}

resource "aws_iam_policy" "ecs_exec_policy" {
  provider    = aws.account
  name        = format("%s-ecs-exec", local.full_fargate_name)
  description = format("Enables sending of remote commands to the %s container via the AWS CLI", local.full_fargate_name)
  policy      = data.aws_iam_policy_document.ecs_exec_policy.json
}


#############################################################
# IAM Policy Attachments
#############################################################
resource "aws_iam_role_policy_attachment" "AmazonECSTaskExecutionRolePolicy" {
  provider   = aws.account
  role       = aws_iam_role.fargate_role["execution"].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  provider   = aws.account
  role       = aws_iam_role.fargate_role["task"].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "AWSXRayDaemonWriteAccess" {
  provider   = aws.account
  count      = local.xray_container == true ? 1 : 0
  role       = aws_iam_role.fargate_role["task"].name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy_attachment" "ecs_exec" {
  provider   = aws.account
  role       = aws_iam_role.fargate_role["task"].name
  policy_arn = aws_iam_policy.ecs_exec_policy.arn
}

resource "aws_iam_role_policy_attachment" "app_mesh" {
  provider   = aws.account
  count      = local.envoy_container == true ? 1 : 0
  role       = aws_iam_role.fargate_role["task"].name
  policy_arn = aws_iam_policy.app_mesh_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "ssm" {
  provider   = aws.account
  for_each   = length(var.parameters) > 0 ? toset(["execution", "task"]) : []
  role       = aws_iam_role.fargate_role[each.value].name
  policy_arn = aws_iam_policy.ssm_policy[0].arn
}


################################################################################
# Elastic File System (EFS)
################################################################################
#############################################################
# File System
#############################################################
resource "aws_efs_file_system" "efs" {
  provider       = aws.account
  count          = var.efs_file_system_name != null ? 1 : 0
  creation_token = var.efs_file_system_name
  encrypted      = true
  kms_key_id     = var.efs_kms_key_arn
  tags = merge(
    var.tags,
    var.default_tags,
    { environment = var.environment
    backup-plan = "standard" }
  )
}

data "aws_iam_policy_document" "efs" {
  statement {
    sid       = "EnforceTLSinTransit"
    effect    = "Deny"
    actions   = ["*"]
    resources = [for v in aws_efs_file_system.efs : v.arn]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "DisableRootAccess"
    effect    = "Allow"
    actions   = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
    resources = [for v in aws_efs_file_system.efs : v.arn]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

resource "aws_efs_file_system_policy" "efs" {
  provider       = aws.account
  count          = var.efs_file_system_name != null ? 1 : 0
  file_system_id = aws_efs_file_system.efs[0].id
  policy         = data.aws_iam_policy_document.efs.json
}

#############################################################
# EFS Access Point
#############################################################
resource "aws_efs_access_point" "access_point" {
  provider       = aws.account
  count          = var.efs_file_system_name != null ? 1 : 0
  file_system_id = aws_efs_file_system.efs[0].id

  posix_user {
    gid = var.efs_user_gid
    uid = var.efs_user_uid
  }

  root_directory {
    path = var.efs_root_path
    creation_info {
      owner_gid   = var.efs_owner_gid
      owner_uid   = var.efs_owner_uid
      permissions = var.efs_root_permissions
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

#############################################################
# EFS Mount Targets
#############################################################
resource "aws_efs_mount_target" "mount_target" {
  provider        = aws.account
  for_each        = var.efs_file_system_name != null ? data.aws_subnet_ids.private.ids : []
  file_system_id  = aws_efs_file_system.efs[0].id
  subnet_id       = each.value
  security_groups = [aws_security_group.mount_target[0].id]
}

resource "aws_security_group" "mount_target" {
  provider               = aws.account
  count                  = var.efs_file_system_name != null ? 1 : 0
  name                   = format("%s-efs", local.full_fargate_name)
  description            = format("allow port 2049 (NFS) access for mounting EFS to %s", local.full_fargate_name)
  vpc_id                 = data.aws_vpc.vpc.id
  revoke_rules_on_delete = true

  tags = merge(
    var.tags,
    var.default_tags,
    {
      environment = var.environment
      Name        = format("%s-efs", local.full_fargate_name)
    }
  )
}

resource "aws_security_group_rule" "mount_nfs" {
  provider                 = aws.account
  for_each                 = var.efs_file_system_name != null ? toset(["ingress", "egress"]) : []
  type                     = each.value
  description              = format("%s NFS connections from %s ECS Tasks", each.value, var.service_name)
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  security_group_id        = aws_security_group.mount_target[0].id
}


################################################################################
# Service Discovery Service
################################################################################
resource "aws_service_discovery_service" "service" {
  provider     = aws.account
  for_each     = var.namespace_id != null ? toset([var.namespace_id]) : []
  name         = local.discovery_name
  namespace_id = var.namespace_id

  dns_config {
    namespace_id = var.namespace_id

    dns_records {
      ttl  = 10
      type = var.namespace_record_type
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}