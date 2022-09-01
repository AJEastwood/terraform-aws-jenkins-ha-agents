output "agent_asg" {
  description = "The name of the agent asg. Use for adding to addition outside resources."
  value       = aws_autoscaling_group.agent_asg.name
}

output "agent_iam_role" {
  description = "The agent IAM role attributes. Use for attaching additional iam policies."
  value       = aws_iam_role.agent_iam_role.name
}
