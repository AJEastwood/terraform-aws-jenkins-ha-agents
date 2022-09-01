
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


data "aws_security_group" "agent_sg" {
  vpc_id = data.aws_vpc.vpc.id

  filter {
    name   = "group-name"
    values = [var.agent_sg_name]
  }
}

data "aws_caller_identity" "current" {}

data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.vpc.id

  tags = {
    Name = var.private_subnet_name
  }
}

data "aws_subnet_ids" "public" {
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

data "aws_ami" "amzn2_ami" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name]
  }
}