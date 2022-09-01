
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
    agent_logs        = aws_cloudwatch_log_group.agent_logs.name
    aws_region        = var.region
    executors         = var.executors
    swarm_version     = var.swarm_version
    jenkins_username  = var.jenkins_username
  }
}

data "template_file" "agent_runcmd" {
  template = file("${path.module}/init/agent-runcmd.cfg")

  vars = {
    api_ssm_parameter = "${var.ssm_parameter}${var.api_ssm_parameter}"
    aws_region        = var.region
    master_asg        = aws_autoscaling_group.master_asg.name
    swarm_version     = var.swarm_version
  }
}

data "template_file" "agent_end" {
  template = file("${path.module}/init/agent-end.cfg")
}
