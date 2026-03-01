# ==============================================================================
# Terraform & AWS Provider 설정
# ==============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# 현재 AWS 계정 정보 가져오기
data "aws_caller_identity" "current" {}

# 가용 영역 정보 가져오기
data "aws_availability_zones" "available" {
  state = "available"
}
