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
# Cloud Watch Log Group
##################################################################

#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "agent_logs" {
  name              = "${var.application}-agent-logs"
  retention_in_days = var.retention_in_days
  tags              = merge(var.tags, { "Name" = "${var.application}-agent-logs" })
}

##################################################################
# Instance Profile
##################################################################

resource "aws_iam_instance_profile" "agent_ip" {
  name = "${var.application}-agent-ip"
  path = "/"
  role = aws_iam_role.agent_iam_role.name
}

##################################################################
# IAM ROLE
##################################################################

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
            "ec2:ResourceTag/Name":["${var.application}-agent"]
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "agent_secret_manager_inline_policy" {
  name = "jenkins-secrets-manager-credentials-provider"
  role = aws_iam_role.agent_iam_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Sid": "AllowGetSecretValue",
          "Effect": "Allow",
          "Action": "secretsmanager:GetSecretValue",
          "Resource": "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:*",
          "Condition":{
            "ForAllValues:StringEquals":{
                "aws:TagKeys": "jenkins:credentials:type"
            }
          }
      },
      {
          "Sid": "AllowListSecretValue",
          "Effect": "Allow",
          "Action": "secretsmanager:ListSecrets",
          "Resource": [
            "*"
          ]
      }
  ]
}
EOF
}

resource "aws_iam_role_policy" "agent_helm_pull_allow_inline_policy" {
  name = "helm-pull-allow"
  role = aws_iam_role.agent_iam_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Sid": "files",
          "Effect": "Allow",
          "Action": [
              "s3:PutObjectAcl",
              "s3:PutObject",
              "s3:GetObjectAcl",
              "s3:GetObject",
              "s3:DeleteObject"
          ],
          "Resource": [
              "arn:aws:s3:::headquarter-youlend-helm-repo/*",
              "arn:aws:s3:::headquarter-youlend-helm-repo"
          ]
      },
      {
          "Sid": "bucket",
          "Effect": "Allow",
          "Action": "s3:ListBucket",
          "Resource": "arn:aws:s3:::headquarter-youlend-helm-repo"
      }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "agent_policy_attachment" {
  role       = aws_iam_role.agent_iam_role.name
  policy_arn = data.aws_iam_policy.ssm_policy.arn
}

##################################################################
# AutoScaling Group
##################################################################

resource "aws_autoscaling_group" "agent_asg" {

  max_size = var.agent_max
  min_size = var.agent_min

  health_check_grace_period = 300
  health_check_type         = "EC2"

  name = "${var.application}-agent-asg"

  vpc_zone_identifier = data.aws_subnets.private.ids

  mixed_instances_policy {

    instances_distribution {
      #on_demand_base_capacity                  = (var.enable_spot_insances==1)?0:100
      on_demand_percentage_above_base_capacity = (var.enable_spot_insances == 1) ? 0 : 100
      spot_instance_pools                      = (var.enable_spot_insances == 1) ? length(var.instance_type) : 0
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.agent_lt.id
        version            = var.agent_lt_version
      }

      override {
        instance_type = var.instance_type[1]
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

##################################################################
# Launch Template
##################################################################

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

  instance_type = var.instance_type[1]
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

  metadata_options {
    http_tokens = "required"
  }
  tags = merge(var.tags, { "Name" = "${var.application}-agent-lt" })
}

##################################################################
# AutoScaling Policy
##################################################################


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
# Seucrity Group
##################################################################

#tfsec:ignore:aws-ec2-no-public-egress-sgr tfsec:ignore:aws-ec2-no-public-ingress-sgr tfsec:ignore:aws-vpc-no-public-egress-sgr
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
    description     = "SSH-22-TCP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All protocols"
  }

  tags = merge(var.tags, { "Name" = "${var.application}-agent-sg" })
}

##################################################################
# Scheduled Actions
##################################################################

# Create a scheduled scaling policy to scale up the ASG during office hours
resource "aws_autoscaling_schedule" "agent_asg_scale_up" {
  scheduled_action_name  = "agent-asg-scale-up"
  min_size               = 1
  max_size               = var.agent_max
  desired_capacity       = var.desired_capacity
  recurrence             = "0 7 * * 1-5" # Monday-Friday at 7am UTC
  time_zone              = "Europe/London"
  autoscaling_group_name = aws_autoscaling_group.agent_asg.name
}

# Create a scheduled scaling policy to scale down the ASG during out-of-office hours
resource "aws_autoscaling_schedule" "agent_asg_scale_down" {
  scheduled_action_name  = "agent-asg-scale-down"
  min_size               = 1
  max_size               = 2
  desired_capacity       = 2
  recurrence             = "0 23 * * *" # every day at 11pm UTC
  time_zone              = "Europe/London"
  autoscaling_group_name = aws_autoscaling_group.agent_asg.name
}