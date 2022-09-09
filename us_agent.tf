  ##################################################################
  # Cloud Watch Log Group
  ##################################################################
resource "aws_cloudwatch_log_group" "us_agent_logs" {
  provider          = aws.us
  name              = "${var.us_application}-agent-logs"
  retention_in_days = var.retention_in_days
  tags              = merge(var.tags, { "Name" = "${var.us_application}-agent-logs" })
}


  ##################################################################
  # Launch Template
  ##################################################################

resource "aws_launch_template" "us_agent_lt" {
  provider    = aws.us
  name        = "${var.us_application}-agent-lt"
  description = "${var.us_application} agent launch template"

  iam_instance_profile {
    name = aws_iam_instance_profile.agent_ip.name
  }

  credit_specification {
    cpu_credits = "standard"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    no_device   = true

    ebs {
      volume_size           = var.agent_volume_size
      encrypted             = true
      delete_on_termination = true
      volume_type           = "gp3"
    }
  }

  image_id      = data.aws_ami.amzn2_ami.id
  key_name      = var.key_name
  ebs_optimized = false

  instance_type = var.instance_type[0]
  user_data     = data.template_cloudinit_config.agent_init.rendered

  monitoring {
    enabled = true
  }

  vpc_security_group_ids = [aws_security_group.us_agent_sg.id]

  tag_specifications {
    resource_type = "instance"
    tags          = local.tags.us_agent
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.tags.us_agent
  }

  tags = merge(var.tags, { "Name" = "${var.us_application}-agent-lt" })
}


  ##################################################################
  # AutoScaling Group
  ##################################################################

resource "aws_autoscaling_group" "us_agent_asg" {
  provider = aws.us
  max_size = var.agent_max
  min_size = var.agent_min

  health_check_grace_period = 300
  health_check_type         = "EC2"

  name = "${var.us_application}-agent-asg"

  vpc_zone_identifier = data.aws_subnet_ids.us_private.ids

  mixed_instances_policy {
    
    instances_distribution {
      #on_demand_base_capacity                  = (var.enable_spot_insances==1)?0:100
      on_demand_percentage_above_base_capacity = (var.enable_spot_insances==1)?0:100
      spot_instance_pools                      = (var.enable_spot_insances==1)?length(var.instance_type):0
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.agent_lt.id
        version            = var.agent_lt_version
      }

     override {
        instance_type = var.instance_type[0]
      }

    }
  }

  dynamic "tag" {
    for_each = local.tags.us_agent
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}


  ##################################################################
  # AutoScaling Policy
  ##################################################################


resource "aws_autoscaling_policy" "us_agent_scale_up_policy" {
  provider               = aws.us
  name                   = "${var.us_application}-agent-up-policy"
  scaling_adjustment     = var.scale_up_number
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 150
  autoscaling_group_name = aws_autoscaling_group.us_agent_asg.name
}

resource "aws_autoscaling_policy" "us_agent_scale_down_policy" {
  name                   = "${var.us_application}-agent-down-policy"
  scaling_adjustment     = var.scale_down_number
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 180
  autoscaling_group_name = aws_autoscaling_group.us_agent_asg.name
}

  ##################################################################
  # Seucrity Group
  ##################################################################
resource "aws_security_group" "us_agent_sg" {
  provider    = aws.us
  name        = "${var.us_application}-agent-sg"
  description = "${var.us_application}-agent-sg"
  vpc_id      = data.aws_vpc.us_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [data.aws_security_group.us_bastion_sg.id]
    self            = false
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { "Name" = "${var.us_application}-agent-sg" })
}







