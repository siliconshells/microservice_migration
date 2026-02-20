output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "service1_instance_ip" {
  description = "Public IP of service1 instance"
  value       = aws_instance.service1.public_ip
}

output "service2_instance_ip" {
  description = "Public IP of service2 instance"
  value       = aws_instance.service2.public_ip
}

output "ecr_service1_url" {
  description = "ECR repository URL for service1"
  value       = aws_ecr_repository.service1.repository_url
}

output "ecr_service2_url" {
  description = "ECR repository URL for service2"
  value       = aws_ecr_repository.service2.repository_url
}
