output "ecs_cluster_name" {
  value = aws_ecs_cluster.ecs_cluster.name
}

output "cluster_security_group" {
  value = aws_security_group.cluster_ec2_compute_sg.id
}

output "default_capacity_provider_name" {
  value = aws_ecs_capacity_provider.cluster_ec2_provider.name
}