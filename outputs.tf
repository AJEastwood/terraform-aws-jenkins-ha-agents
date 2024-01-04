output "agent_asg" {
  description = "The name of the agent asg. Use for adding to addition outside resources."
  value       = aws_autoscaling_group.agent_asg.name
}

output "agent_iam_role" {
  description = "The agent IAM role attributes. Use for attaching additional iam policies."
  value       = aws_iam_role.agent_iam_role.name
}


output "master_asg" {
  description = "The name of the master asg. Use for adding to addition outside resources."
  value       = aws_autoscaling_group.master_asg.name
}

output "master_asg_id" {
  description = "The ID of the master asg."
  value       = aws_security_group.master_sg.id
}

output "master_iam_role" {
  description = "The master IAM role name. Use for attaching additional iam policies."
  value       = aws_iam_role.master_iam_role.name
}

output "lb_dns_name" {
  value       = aws_lb.private_lb.dns_name
  description = "The DNS name of the load balancer."
}

output "lb_zone_id" {
  value       = aws_lb.private_lb.zone_id
  description = "The canonical hosted zone ID of the load balancer."
}

output "r53_record" {
  description = "The fqdn of the route 53 record."
  value       = aws_route53_record.r53_record.fqdn
}
