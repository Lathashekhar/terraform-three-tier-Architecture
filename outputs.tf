output "alb_dns_name" {
  value = aws_lb.web_alb.dns_name
}

output "web_asg_name" {
  value = aws_autoscaling_group.web_asg.name
}

output "app_asg_name" {
  value = aws_autoscaling_group.app_asg.name
}

output "db_endpoint" {
  value = aws_db_instance.db.endpoint
}

output "vpc_id" {
  value = aws_vpc.main.id
}
