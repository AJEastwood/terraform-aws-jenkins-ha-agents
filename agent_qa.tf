##################################################################
# AutoScaling Group
##################################################################

resource "aws_autoscaling_group" "agent_qa_asg" {

  max_size = "2"
  min_size = "1"

  health_check_grace_period = 300
  health_check_type         = "EC2"

  name = "${var.application}-qa-agent-asg"

  vpc_zone_identifier = data.aws_subnet_ids.private.ids

  mixed_instances_policy {

    instances_distribution {
      on_demand_percentage_above_base_capacity = (var.enable_spot_insances == 1) ? 0 : 100
      spot_instance_pools                      = (var.enable_spot_insances == 1) ? length(var.instance_type) : 0
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.agent_qa_lt.id
        version            = var.agent_lt_version
      }

      override {
        instance_type = var.instance_type[0]
      }

    }
  }

  dynamic "tag" {
    for_each = local.tags.agent_qa
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

##################################################################
# Launch Template
##################################################################

resource "aws_launch_template" "agent_qa_lt" {
  name        = "${var.application}-agent-qa-lt"
  description = "${var.application} database agent launch template"

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
  user_data     = data.template_cloudinit_config.agent_qa_init.rendered

  monitoring {
    enabled = true
  }

  vpc_security_group_ids = [aws_security_group.agent_sg.id]

  tag_specifications {
    resource_type = "instance"
    tags          = local.tags.agent_qa
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.tags.agent_qa
  }

  metadata_options {
    http_tokens = "required"
  }
  tags = merge(var.tags, { "Name" = "${var.application}-agent-qa-lt" })
}

##################################################################
# AutoScaling Policy
##################################################################


resource "aws_autoscaling_policy" "agent_qa_scale_up_policy" {
  name                   = "${var.application}-agent-qa-up-policy"
  scaling_adjustment     = var.scale_up_number_qa
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 150
  autoscaling_group_name = aws_autoscaling_group.agent_qa_asg.name
}

resource "aws_autoscaling_policy" "agent_qa_scale_down_policy" {
  name                   = "${var.application}-agent-qa-down-policy"
  scaling_adjustment     = var.scale_down_number_qa
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 180
  autoscaling_group_name = aws_autoscaling_group.agent_qa_asg.name
}

##################################################################
# Scheduled Actions
##################################################################

# Create a scheduled scaling policy to scale up the ASG during office hours
resource "aws_autoscaling_schedule" "agent_qa_asg_scale_up" {
  scheduled_action_name  = "agent-qa-asg-scale-up"
  min_size               = 1
  max_size               = 2
  desired_capacity       = 2
  recurrence             = "0 7 * * 1-5" # Monday-Friday at 7am UTC
  time_zone              = "Europe/London"
  autoscaling_group_name = aws_autoscaling_group.agent_qa_asg.name
}

# Create a scheduled scaling policy to scale down the ASG during out-of-office hours
resource "aws_autoscaling_schedule" "agent_qa_asg_scale_down" {
  scheduled_action_name  = "agent-qa-asg-scale-down"
  min_size               = 1
  max_size               = 1
  desired_capacity       = 1
  recurrence             = "0 23 * * *" # every day at 11pm UTC
  time_zone              = "Europe/London"
  autoscaling_group_name = aws_autoscaling_group.agent_qa_asg.name
}