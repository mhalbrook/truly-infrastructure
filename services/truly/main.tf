###########################################################################
# DNS Records
###########################################################################
module "dns" {
  source        = "./modules/dns"
  count         = try(length([data.terraform_remote_state.certificates.outputs.truly_domain]), 0)
  environment   = terraform.workspace
  record_name   = try(data.terraform_remote_state.certificates.outputs.truly_domain, null)
  record_type   = "A"
  record_values = module.alb.load_balancer_dns_name
  alias         = true
  zone_id       = module.alb.load_balancer_zone_id
  health_check  = false

  providers = {
    aws.account = aws
  }
}

###########################################################################
# Load Balancers
###########################################################################
module "alb" {
  source                     = "./modules/alb"
  project                    = var.project
  environment                = terraform.workspace
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id
  service_name               = var.service_name
  load_balancer_type         = "application"
  certificate_arns           = try([data.terraform_remote_state.certificates.outputs.truly_arn], null)
  subnet_layer               = "public"
  deregistration_delay       = 5
  enable_deletion_protection = false
  listeners = try(data.terraform_remote_state.certificates.outputs.truly_arn, null) == null ? {
    80 = {
      target_group_name = "truly"
      certificate_arns  = []
    }
  } : null
  target_groups = {
    truly = {
      port                  = 8080
      protocol              = "HTTP"
      type                  = "ip"
      health_check_path     = "/"
      health_check_protocol = "HTTP"
    }
  }
  listener_rules = {
    truly = {
      action            = "forward"
      priority          = 1
      listener_port     = 443
      target_group_name = "truly"
      host_header       = ["truly.halbromr.com"]
      path_pattern      = {}
      http_header       = {}
    }
  }

  providers = {
    aws.account = aws
  }
}


################################################################################
# ECS Fargate Service
################################################################################
##########################################################
# ECS Fargate Cluster
##########################################################
module "ecs_cluster" {
  source          = "./modules/ecs_cluster"
  environment     = terraform.workspace
  project         = var.project
  cluster_name    = var.service_name
  enable_ecs_exec = true

  providers = {
    aws.account = aws
  }
}


##########################################################
# ECS Fargate Service
##########################################################
module "truly" {
  source                       = "./modules/truly"
  project                      = var.project
  environment                  = terraform.workspace
  cluster_name                 = module.ecs_cluster.cluster_name
  cluster_id                   = module.ecs_cluster.cluster_id
  service_name                 = var.service_name
  vpc_id                       = data.terraform_remote_state.vpc.outputs.vpc_id
  app_port                     = 8080
  image                        = "truly-clojure-demo"
  container_cpu_units          = 512
  container_memory             = 1024
  desired_capacity             = 1
  max_capacity                 = 5
  load_balancer_type           = "application"
  load_balancer_arn            = module.alb.load_balancer_arn
  target_group_arn             = element(module.alb.target_group_arns, 0)
  load_balancer_security_group = element(module.alb.load_balancer_security_group_id, 0)
  parameters                   = { for k, v in module.truly_parameters : k => v.ssm_arn }

  providers = {
    aws.account = aws
    aws.cicd    = aws
  }
}

module "truly_parameters" {
  source       = "./modules/parameters"
  for_each     = var.truly_parameters
  environment  = terraform.workspace
  name         = each.key
  description  = each.value.description
  tier         = each.value.tier
  value        = each.value.value
  service_name = each.value.service

  providers = {
    aws.account = aws
  }
}


################################################################################
# Build Resources
################################################################################
##########################################################
#  KMS Key
##########################################################
module "deployment_kms" {
  source      = "./modules/kms"
  environment = terraform.workspace
  service     = "deployment"

  providers = {
    aws.account   = aws
    aws.secondary = aws
  }
}

##########################################################
# Elastic Conatiner Repository
##########################################################
module "ecr" {
  source       = "./modules/ecr"
  environment  = terraform.workspace
  service_name = var.service_name
  project      = var.project
  kms_key_arn  = module.deployment_kms.key_arn[data.aws_region.region.name]

  providers = {
    aws.account = aws
  }
}

##########################################################
# CodeBuild Project
##########################################################
module "codebuild" {
  source          = "./modules/codebuild"
  environment     = terraform.workspace
  project         = var.project
  service_name    = var.service_name
  source_provider = "GitHub"
  source_location = "https://github.com/mhalbrook/truly.git"
  source_version  = "main"
  kms_key_arn     = module.deployment_kms.key_arn[data.aws_region.region.name]
  environment_variables = {
    ENV_TAG = terraform.workspace
  }

  providers = {
    aws.account = aws
  }
}