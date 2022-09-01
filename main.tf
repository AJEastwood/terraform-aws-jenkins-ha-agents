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

  ##################################################################
  # Cloud Watch Alarms
  ##################################################################
resource "aws_cloudwatch_metric_alarm" "available_executors_low" {
  alarm_name          = "${var.application}-available-executors-low"
  alarm_description   = "Alarm if the number of available executors are two low."
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "AvailableExecutors"
  namespace           = "JenkinsBuildActiveQueue"
  period              = 30
  statistic           = "Minimum"
  threshold           = var.agent_min * var.executors / 2

  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.agent_asg.name
  }

  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.agent_scale_up_policy.arn]
}

resource "aws_cloudwatch_metric_alarm" "idle_executors_high" {
  alarm_name          = "${var.application}-idle-executors-high"
  alarm_description   = "Alarm if too many executors exist."
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 10
  metric_name         = "IdleExecutors"
  namespace           = "JenkinsBuildActiveQueue"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0

  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.agent_asg.name
  }

  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.agent_scale_down_policy.arn]
}

resource "aws_cloudwatch_metric_alarm" "agent_cpu_alarm" {
  alarm_name          = "${var.application}-agent-cpu-alarm"
  alarm_description   = "Alarm if agent CPU is too high."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 75

  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.agent_asg.name
  }

  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.agent_scale_up_policy.arn]
}

  ##################################################################
  # Agent Node
  ##################################################################

resource "aws_autoscaling_group" "agent_asg" {
  # depends_on = [aws_autoscaling_group.master_asg]

  max_size = var.agent_max
  min_size = var.agent_min

  health_check_grace_period = 300
  health_check_type         = "EC2"

  name = "${var.application}-agent-asg"

  vpc_zone_identifier = data.aws_subnet_ids.private.ids

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
    for_each = local.tags.agent
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_launch_template" "agent_lt" {
  name        = "${var.application}-agent-lt"
  description = "${var.application} agent launch template"

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

  vpc_security_group_ids = [aws_security_group.agent_sg.id]

  tag_specifications {
    resource_type = "instance"
    tags          = local.tags.agent
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.tags.agent
  }

  tags = merge(var.tags, { "Name" = "${var.application}-agent-lt" })
}

resource "aws_security_group" "agent_sg" {
  name        = "${var.application}-agent-sg"
  description = "${var.application}-agent-sg"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [data.aws_security_group.bastion_sg.id]
    self            = false
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { "Name" = "${var.application}-agent-sg" })
}

resource "aws_iam_instance_profile" "agent_ip" {
  name = "${var.application}-agent-ip"
  path = "/"
  role = aws_iam_role.agent_iam_role.name
}

resource "aws_iam_role" "agent_iam_role" {
  name = "${var.application}-agent-iam-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

  tags = merge(var.tags, { "Name" = "${var.application}-agent-iam-role" })
}

resource "aws_iam_role_policy" "agent_inline_policy" {
  name = "${var.application}-agent-inline-policy"
  role = aws_iam_role.agent_iam_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:DescribeInstances",
        "autoscaling:DescribeAutoScalingGroups",
        "ecr:DescribeImages"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "${aws_cloudwatch_log_group.agent_logs.arn}:*"
    },
    {
      "Action": [
        "sts:AssumeRole"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": "ssm:GetParameter",
      "Effect": "Allow",
      "Resource": [
        "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter}${var.api_ssm_parameter}"
      ]
    },
    {
      "Action": "ec2:TerminateInstances",
      "Effect": "Allow",
      "Resource":[
        "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*"
      ],
      "Condition":{
        "StringEquals":{
            "ec2:ResourceTag/Name":"${var.application}-agent"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "agent_policy_attachment" {
  role       = aws_iam_role.agent_iam_role.name
  policy_arn = data.aws_iam_policy.ssm_policy.arn
}

resource "aws_cloudwatch_log_group" "agent_logs" {
  name              = "${var.application}-agent-logs"
  retention_in_days = var.retention_in_days
  tags              = merge(var.tags, { "Name" = "${var.application}-agent-logs" })
}



resource "aws_autoscaling_policy" "agent_scale_up_policy" {
  name                   = "${var.application}-agent-up-policy"
  scaling_adjustment     = var.scale_up_number
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 150
  autoscaling_group_name = aws_autoscaling_group.agent_asg.name
}

resource "aws_autoscaling_policy" "agent_scale_down_policy" {
  name                   = "${var.application}-agent-down-policy"
  scaling_adjustment     = var.scale_down_number
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 180
  autoscaling_group_name = aws_autoscaling_group.agent_asg.name
}

  ##################################################################
  # Master Node 
  ##################################################################
resource "aws_autoscaling_group" "master_asg" {
  count      = var.enable_master_node == true ? 1 : 0 
  depends_on = [aws_efs_mount_target.mount_targets]

  max_size = 1
  min_size = 1

  health_check_grace_period = 1200
  health_check_type         = "ELB"

  name = "${var.application}-master-asg"

  vpc_zone_identifier = data.aws_subnet_ids.private.ids

  target_group_arns = [aws_lb_target_group.master_tg.arn]

  mixed_instances_policy {

    instances_distribution {
      on_demand_percentage_above_base_capacity = 100
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.master_lt.id
        version            = var.master_lt_version
      }

      override {
        instance_type = var.instance_type[0]
      }

    }
  }

  dynamic "tag" {
    for_each = local.tags.master
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_launch_template" "master_lt" {
  count       = var.enable_master_node == true ? 1 : 0 
  name        = "${var.application}-master-lt"
  description = "${var.application} master launch template"

  iam_instance_profile {
    name = aws_iam_instance_profile.master_ip.name
  }

  credit_specification {
    cpu_credits = "standard"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    no_device   = true

    ebs {
      volume_size           = 25
      encrypted             = true
      delete_on_termination = true
      volume_type           = "gp3"
    }
  }

  image_id      = data.aws_ami.amzn2_ami.id
  key_name      = var.key_name
  ebs_optimized = false

  instance_type = var.instance_type[0]
  user_data     = data.template_cloudinit_config.master_init.rendered

  monitoring {
    enabled = true
  }

  vpc_security_group_ids = [aws_security_group.master_sg.id]

  tag_specifications {
    resource_type = "instance"
    tags          = local.tags.master
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.tags.master
  }

  tags = merge(var.tags, { "Name" = "${var.application}-master-lt" })
}

resource "aws_security_group" "master_sg" {
  count       = var.enable_master_node == true ? 1 : 0 
  name        = "${var.application}-master-sg"
  description = "${var.application}-master-sg"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id, aws_security_group.agent_sg.id]
    self            = false
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [data.aws_security_group.bastion_sg.id]
    self            = false
  }

  ingress {
    from_port       = 49817
    to_port         = 49817
    protocol        = "tcp"
    security_groups = [aws_security_group.agent_sg.id]
    self            = false
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { "Name" = "${var.application}-master-sg" })
}

resource "aws_iam_instance_profile" "master_ip" {
  count = var.enable_master_node == true ? 1 : 0 
  name  = "${var.application}-master-ip"
  path  = "/"
  role  = aws_iam_role.master_iam_role[count.index].name
}

resource "aws_iam_role" "master_iam_role" {
  count = var.enable_master_node == true ? 1 : 0 
  name  = "${var.application}-master-iam-role"
  path  = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

  tags = merge(var.tags, { "Name" = "${var.application}-master-iam-role" })
}

resource "aws_iam_role_policy" "master_inline_policy" {
  count = var.enable_master_node == true ? 1 : 0 
  name = "${var.application}-master-inline-policy"
  role = aws_iam_role.master_iam_role[count.index].id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ec2:DescribeInstances",
        "autoscaling:DescribeAutoScalingGroups"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Effect": "Allow",
      "Resource": "${aws_cloudwatch_log_group.master_logs[count.index].arn}:*"
    },
    {
      "Action": [
        "sts:AssumeRole"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": "ssm:PutParameter",
      "Effect": "Allow",
      "Resource": [
        "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter}${var.api_ssm_parameter}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "master_policy_attachment" {
  count      = var.enable_master_node == true ? 1 : 0 
  role       = aws_iam_role.master_iam_role[count.index].name
  policy_arn = data.aws_iam_policy.ssm_policy.arn
}

resource "aws_cloudwatch_log_group" "master_logs" {
  count             = var.enable_master_node == true ? 1 : 0 
  name              = "${var.application}-master-logs"
  retention_in_days = var.retention_in_days
  tags              = merge(var.tags, { "Name" = "${var.application}-master-logs" })
}

resource "aws_efs_mount_target" "mount_targets" {
  for_each = {for k, v in toset(data.aws_subnet_ids.private.ids): k => v if var.enable_master_node}
  file_system_id  = aws_efs_file_system.master_efs.id
  subnet_id       = each.key
  security_groups = [aws_security_group.master_storage_sg[0].id]
}

resource "aws_security_group" "master_storage_sg" {
  count       = var.enable_master_node == true ? 1 : 0 
  name        = "${var.application}-master-storage-sg"
  description = "${var.application}-master-storage-sg"
  vpc_id      = data.aws_vpc.vpc.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.master_sg[count.index].id]
    self            = false
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { "Name" = "${var.application}-master-storage-sg" })
}

resource "aws_lb_target_group" "master_tg" {
  count   = var.enable_master_node == true ? 1 : 0 
  name    = "${var.application}-master-tg"

  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = data.aws_vpc.vpc.id
  deregistration_delay = 30

  health_check {
    port                = "traffic-port"
    path                = "/login"
    timeout             = 120
    healthy_threshold   = 2
    unhealthy_threshold = 10
    matcher             = "200-299"
    interval = 300
  }

  tags = merge(var.tags, { "Name" = "${var.application}-master-tg" })
}

resource "aws_lb_listener" "master_lb_listener" {
  count             = var.enable_master_node == true ? 1 : 0 
  load_balancer_arn = aws_lb.lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = data.aws_acm_certificate.certificate.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.master_tg[count.index].arn
  }
}

resource "aws_lb_listener" "master_http_listener" {
  count             = var.enable_master_node == true ? 1 : 0 
  load_balancer_arn = aws_lb.lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_ssm_parameter" "admin_password" {
  count       = var.enable_master_node == true ? 1 : 0 
  name        = "${var.ssm_parameter}${var.password_ssm_parameter}"
  description = "${var.application}-admin-password"
  type        = "SecureString"
  value       = var.admin_password
  overwrite   = true
}
  
  

