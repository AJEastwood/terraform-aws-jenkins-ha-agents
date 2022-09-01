terraform {
  required_version = ">= 0.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.25"
    }
    template = {
      source  = "hashicorp/template"
      version = ">= 2.1"
    }
  }
}

module "master_node" {
  count                       = var.enable_master_node == true ? 1 : 0
  source                      = "./modules/master"
  admin_password              = var.admin_password
  agent_min                   = var.agent_min
  bastion_sg_name             = var.bastion_sg_name
  agent_sg_name               = var.agent_sg_name
  ami_name                    = var.ami_name
  ami_owner                   = var.ami_owner
  vpc_name                    = var.vpc_name
  jenkins_username            = var.jenkins_username
  private_subnet_name         = var.private_subnet_name
  public_subnet_name          = var.public_subnet_name
  cidr_ingress                = var.cidr_ingress
  efs_mode                    = var.efs_mode
  efs_provisioned_throughput  = var.efs_provisioned_throughput
  api_ssm_parameter           = var.api_ssm_parameter
  application                 = var.application
  key_name                    = var.key_name
  auto_update_plugins_cron    = var.auto_update_plugins_cron
  custom_plugins              = var.custom_plugins
  extra_master_userdata       = var.extra_master_userdata
  extra_master_userdata_merge = var.extra_master_userdata_merge
  retention_in_days           = var.retention_in_days
  executors                   = var.executors
  instance_type               = var.instance_type
  jenkins_version             = var.jenkins_version
  password_ssm_parameter      = var.password_ssm_parameter
  region                      = var.region
  ssl_certificate             = var.ssl_certificate
  ssm_parameter               = var.ssm_parameter
  domain_name                 = var.domain_name
  r53_record                  = var.r53_record
  tags                        = var.tags
}

module "agent_node" {
  source                      = "./modules/agent"
  jenkins_username            = var.jenkins_username
  agent_max                   = var.agent_max
  agent_min                   = var.agent_min
  agent_volume_size           = var.agent_volume_size
  private_subnet_name         = var.private_subnet_name
  bastion_sg_name             = var.bastion_sg_name
  api_ssm_parameter           = var.api_ssm_parameter
  ami_name                    = var.ami_name
  ami_owner                   = var.ami_owner
  vpc_name                    = var.vpc_name
  application                 = var.application
  key_name                    = var.key_name
  scale_down_number           = var.scale_down_number
  scale_up_number             = var.scale_up_number
  extra_agent_userdata        = var.extra_agent_userdata
  extra_agent_userdata_merge  = var.extra_agent_userdata_merge
  retention_in_days           = var.retention_in_days
  executors                   = var.executors
  instance_type               = var.instance_type
  region                      = var.region
  ssm_parameter               = var.ssm_parameter
  swarm_version               = var.swarm_version
  tags                        = var.tags
  enable_spot_insances        = var.enable_spot_insances
  }
  
  

