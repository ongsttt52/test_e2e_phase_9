# ==============================================================================
# 출력값 (terraform apply 후 표시)
# ==============================================================================




# 애플리케이션 URL (Elastic IP)
output "app_url" {
  description = "애플리케이션 접속 URL"
  value       = "http://${aws_eip.ec2.public_ip}"
}

# EC2 Public IP
output "ec2_public_ip" {
  description = "EC2 인스턴스 Public IP"
  value       = aws_eip.ec2.public_ip
}

# SSH 접속 명령어
output "ssh_command" {
  description = "EC2 SSH 접속 명령어"
  value       = "ssh -i ~/.ssh/${local.project_name_normalized}-ec2-key ec2-user@${aws_eip.ec2.public_ip}"
}


# S3 버킷 이름 (공통)
output "s3_bucket_name" {
  description = "미디어 파일 저장 S3 버킷"
  value       = aws_s3_bucket.media.bucket
}

# 리전 정보 (공통)
output "aws_region" {
  description = "AWS 리전"
  value       = var.aws_region
}
