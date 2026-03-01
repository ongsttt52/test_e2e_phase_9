# Terraform State Backend Configuration
# 프로젝트별 전용 S3 버킷에 state를 저장합니다.
# 버킷은 GitHub Actions 또는 deploy.sh에서 자동 생성됩니다.
# 버킷: test-e2e-phase-9-state-bucket
# 경로: test_e2e_phase_9/<environment>/terraform.tfstate

terraform {
  backend "s3" {
    bucket = "test-e2e-phase-9-state-bucket"
    key    = "test_e2e_phase_9/demo/terraform.tfstate"
    region = "ap-northeast-2"
    encrypt = true
  }
}
