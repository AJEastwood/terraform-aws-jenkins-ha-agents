data "aws_caller_identity" "current" {}

data "aws_security_group" "bastion_sg" {
  vpc_id = data.aws_vpc.vpc.id

  filter {
    name   = "group-name"
    values = [var.bastion_sg_name]
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

data "aws_vpc" "vpc" {
  tags = {
    Name = var.vpc_name
  }
}

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

data "aws_route53_zone" "r53_zone" {
  name = var.domain_name
}

data "aws_iam_policy" "ssm_policy" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}