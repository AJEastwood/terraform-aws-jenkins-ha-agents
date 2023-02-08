
##################################################################
# Agent User Data
##################################################################
data "template_cloudinit_config" "agent_init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "agent.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.agent_write_files.rendered
  }

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.agent_runcmd.rendered
  }

  part {
    content_type = "text/cloud-config"
    content      = var.extra_agent_userdata
    merge_type   = var.extra_agent_userdata_merge
  }

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.agent_end.rendered
    merge_type   = "list(append)+dict(recurse_array)+str()"
  }
}

data "template_file" "agent_write_files" {
  template = file("${path.module}/init/agent-write-files.cfg")

  vars = {
    swarm_label      = "swarm-eu" #All Labels you want Agent to have must be separated with space
    agent_logs       = aws_cloudwatch_log_group.agent_logs.name
    aws_region       = var.region
    executors        = var.executors
    swarm_version    = var.swarm_version
    jenkins_username = var.jenkins_username
  }
}

data "template_file" "agent_runcmd" {
  template = file("${path.module}/init/agent-runcmd.cfg")

  vars = {
    api_ssm_parameter = "${var.ssm_parameter}${var.api_ssm_parameter}"
    aws_master_region = var.aws_master_region
    master_asg        = aws_autoscaling_group.master_asg.name
    swarm_version     = var.swarm_version
  }
}

data "template_file" "agent_end" {
  template = file("${path.module}/init/agent-end.cfg")
}

##################################################################
# US Agent User Data
##################################################################
data "template_cloudinit_config" "usagent_init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "agent.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.usagent_write_files.rendered
  }

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.agent_runcmd.rendered
  }

  part {
    content_type = "text/cloud-config"
    content      = var.extra_agent_userdata
    merge_type   = var.extra_agent_userdata_merge
  }

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.agent_end.rendered
    merge_type   = "list(append)+dict(recurse_array)+str()"
  }
}

data "template_file" "usagent_write_files" {
  template = file("${path.module}/init/usagent-write-files.cfg")

  vars = {
    swarm_label      = "swarm-us" #All Labels you want Agent to have must be separated with space
    agent_logs       = aws_cloudwatch_log_group.agent_logs.name
    aws_region       = var.us_agent_region
    executors        = var.executors
    swarm_version    = var.swarm_version
    jenkins_username = var.jenkins_username
  }
}

##################################################################
# Master User Data
##################################################################
data "template_cloudinit_config" "master_init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "master.cfg"
    content_type = "text/cloud-config"
    content      = data.template_file.master_write_files.rendered
  }

  part {
    content_type = "text/cloud-config"
    content      = var.custom_plugins
    merge_type   = "list(append)+dict(recurse_array)+str()"
  }

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.master_runcmd.rendered
  }

  part {
    content_type = "text/cloud-config"
    content      = var.extra_master_userdata
    merge_type   = var.extra_master_userdata_merge
  }

  part {
    content_type = "text/cloud-config"
    content      = data.template_file.master_end.rendered
    merge_type   = "list(append)+dict(recurse_array)+str()"
  }
}

data "template_file" "master_write_files" {
  template = file("${path.module}/init/master-write-files.cfg")

  vars = {
    admin_password           = var.admin_password
    api_ssm_parameter        = "${var.ssm_parameter}${var.api_ssm_parameter}"
    application              = var.application
    auto_update_plugins_cron = var.auto_update_plugins_cron
    aws_region               = var.region
    executors_min            = var.agent_min * var.executors
    master_logs              = aws_cloudwatch_log_group.master_logs.name
    #jenkins_username  = var.jenkins_username

  }
}

data "template_file" "master_runcmd" {
  template = file("${path.module}/init/master-runcmd.cfg")

  vars = {
    admin_password  = var.admin_password
    aws_region      = var.region
    jenkins_version = var.jenkins_version
    master_storage  = aws_efs_file_system.master_efs.id
    #jenkins_username  = var.jenkins_username

  }
}

data "template_file" "master_end" {
  template = file("${path.module}/init/master-end.cfg")
}

resource "aws_efs_file_system" "master_efs" {
  creation_token   = "${var.application}-master-efs"
  encrypted        = true
  performance_mode = "generalPurpose"

  throughput_mode                 = var.efs_mode
  provisioned_throughput_in_mibps = var.efs_mode == "provisioned" ? var.efs_provisioned_throughput : null

  tags = merge(var.tags, { "Name" = "${var.application}-master-efs" })
}

data "aws_security_group" "bastion_sg" {
  vpc_id = data.aws_vpc.vpc.id

  filter {
    name   = "group-name"
    values = [var.bastion_sg_name]
  }
}

data "aws_security_group" "us_bastion_sg" {
  provider = aws.us
  vpc_id   = data.aws_vpc.us_vpc.id

  filter {
    name   = "group-name"
    values = [var.us_bastion_sg_name]
  }
}

data "aws_caller_identity" "current" {}

data "aws_subnet" "private" {
  vpc_id = data.aws_vpc.vpc.id

  tags = {
    Name = var.private_subnet_name
  }
}

data "aws_subnet" "us_private" {
  provider = aws.us
  vpc_id   = data.aws_vpc.us_vpc.id
  tags = {
    Name = var.us_private_subnet_name
  }
}

data "aws_subnet" "public" {
  vpc_id = data.aws_vpc.vpc.id

  tags = {
    Name = var.public_subnet_name
  }
}

data "aws_acm_certificate" "certificate" {
  domain   = var.ssl_certificate
  statuses = ["ISSUED"]
}

data "aws_iam_policy" "ssm_policy" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_route53_zone" "r53_zone" {
  name = var.domain_name
}



data "aws_vpc" "vpc" {
  tags = {
    Name = var.vpc_name
  }
}

data "aws_vpc" "us_vpc" {
  provider = aws.us
  tags = {
    Name = var.us_vpc_name
  }
}



data "aws_ami" "amzn2_ami" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name]
  }
}

data "aws_ami" "us_amzn2_ami" {
  provider    = aws.us
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.us_ami_name]
  }
}
