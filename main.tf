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
  ##################################################################
  # Load Balancer
  ##################################################################
resource "aws_lb" "lb" {
  name                       = "${var.application}-lb"
  idle_timeout               = 60
  internal                   = false
  security_groups            = [aws_security_group.lb_sg.id]
  subnets                    = data.aws_subnet_ids.public.ids
  enable_deletion_protection = false

  tags = merge(var.tags, { "Name" = "${var.application}-lb" })
}

resource "aws_security_group" "lb_sg" {
  name        = "${var.application}-lb-sg"
  description = "${var.application}-lb-sg"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.cidr_ingress
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.cidr_ingress
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { "Name" = "${var.application}-lb-sg" })
}

  ##################################################################
  # Route 53
  ##################################################################


resource "aws_route53_record" "r53_record" {
  zone_id = data.aws_route53_zone.r53_zone.zone_id
  name    = var.r53_record
  type    = "A"

  alias {
    name                   = "dualstack.${aws_lb.lb.dns_name}"
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = false
  }
}

module "master_node" {
  count                       = var.enable_master_node == true ? 1 : 0
  source                      = "./modules/master"
  admin_password              = var.admin_password
  jenkins_username            = var.jenkins_username
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
  ssm_parameter               = var.ssm_parameter
  tags                        = var.tags
}

module "agent_node" {
  source                      = "./modules/agent"
  jenkins_username            = var.jenkins_username
  agent_max                   = var.agent_max
  agent_min                   = var.agent_min
  agent_volume_size           = var.agent_volume_size
  api_ssm_parameter           = var.api_ssm_parameter
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
  
  

