output "service_elb_name" {
  value = aws_lb.app_load_balancer.dns_name
  description = "ALB DNS name"
}