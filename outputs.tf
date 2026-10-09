output "ami_id" {
  value = data.aws_ami.ubuntu.id
}

output "public_ip" {
  value = aws_instance.server.public_ip
}

output "agent_public_ips" {
  value = aws_instance.agent[*].public_ip
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}