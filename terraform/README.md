# Terraform AWS 인프라 가이드

이 디렉토리에는 AWS 인프라를 자동으로 생성하는 Terraform 코드가 있습니다.

## 생성되는 AWS 리소스

- **S3**: 미디어 파일 저장소
- **VPC**: 격리된 네트워크 (Public/Private 서브넷)
- **RDS PostgreSQL**: 데이터베이스
- **ElastiCache Redis**: 캐시 및 Celery 브로커
- **ECR**: Docker 이미지 저장소
- **ECS Fargate**: 컨테이너 실행 환경
- **Application Load Balancer**: 트래픽 분산
- **IAM**: 권한 설정
- **CloudWatch**: 로그 저장

## 사전 준비

### 1. Terraform 설치
```bash
# macOS
brew install terraform

# Windows (Chocolatey)
choco install terraform

# 설치 확인
terraform version
```

### 2. AWS CLI 설치 및 설정
```bash
# AWS CLI 설치
brew install awscli  # macOS
# 또는 https://aws.amazon.com/cli/

# AWS 자격증명 설정
aws configure
# AWS Access Key ID: [입력]
# AWS Secret Access Key: [입력]
# Default region name: ap-northeast-2
# Default output format: json
```

## 사용 방법

### 1단계: 인프라 생성

```bash
# terraform 디렉토리로 이동
cd terraform/

# Terraform 초기화 (최초 1회)
terraform init

# 생성될 리소스 미리보기
terraform plan

# 실제 인프라 생성 (5~10분 소요)
terraform apply

# "yes" 입력 → 엔터
```

### 2단계: 출력값 확인

```bash
# 모든 출력값 보기
terraform output

# 애플리케이션 URL만 보기
terraform output app_url
# → http://my-app-alb-123456.ap-northeast-2.elb.amazonaws.com

# ECR 주소 보기
terraform output ecr_repository_url
# → 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/my-project-dev
```

### 3단계: Docker 이미지 빌드 및 배포

```bash
# 프로젝트 루트로 이동
cd ..

# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin $(terraform -chdir=terraform output -raw ecr_repository_url | cut -d'/' -f1)

# Docker 이미지 빌드
docker build -t test_e2e_phase_9 ./backend

# 이미지 태깅
docker tag test_e2e_phase_9:latest $(terraform -chdir=terraform output -raw ecr_repository_url):latest

# ECR에 푸시
docker push $(terraform -chdir=terraform output -raw ecr_repository_url):latest

# ECS 서비스 재시작 (새 이미지 배포)
aws ecs update-service \
  --cluster $(terraform -chdir=terraform output -raw ecs_cluster_name) \
  --service $(terraform -chdir=terraform output -raw ecs_service_name) \
  --force-new-deployment \
  --region ap-northeast-2
```

### 4단계: 애플리케이션 접속

```bash
# URL 확인
terraform -chdir=terraform output app_url

# 브라우저에서 접속
open $(terraform -chdir=terraform output -raw app_url)
```

## 환경 설정

### demo 환경 (클라이언트 데모 - 기본값)
```bash
terraform apply
# 기본값: environment=demo
# - 작은 인스턴스 (비용 절감, 빠른 생성)
# - S3 파일 30일 후 자동 삭제
# - 스냅샷 생략 (빠른 삭제)
# - 쉬운 삭제 가능
```

### dev 환경 (로컬 개발용)
```bash
terraform apply -var="environment=dev"
# - demo와 동일한 설정
# - 로컬 테스트용
```

### prod 환경 (프로덕션)
```bash
terraform apply -var="environment=prod"
# - 큰 인스턴스 (성능 우선)
# - 백업 7일 보관
# - 삭제 방지 정책
```

### 데이터베이스 비밀번호 변경
```bash
terraform apply -var="db_password=my-secure-password-123"
```

## 인프라 삭제

```bash
cd terraform/

# 삭제될 리소스 미리보기
terraform plan -destroy

# 전체 인프라 삭제
terraform destroy

# "yes" 입력 → 엔터
```

**주의:**
- demo/dev 환경: S3 파일 포함 모두 삭제
- prod 환경: S3 버킷에 파일이 있으면 삭제 실패 (데이터 보호)

## 트러블슈팅

### 에러: "S3 bucket is not empty"
```bash
# S3 버킷 비우기
aws s3 rm s3://$(terraform output -raw s3_bucket_name) --recursive

# 다시 삭제 시도
terraform destroy
```

### 에러: "DeletionProtection is enabled"
```bash
# RDS 삭제 방지 해제 (주의: 데이터 손실 가능)
# rds.tf 파일에서 deletion_protection = false로 변경
terraform apply
terraform destroy
```

### 로그 확인
```bash
# ECS 컨테이너 로그 보기
aws logs tail /ecs/test_e2e_phase_9-demo --follow --region ap-northeast-2
```

## 비용 추정

### demo/dev 환경 (월 예상)
- RDS db.t3.micro: ~$15
- ElastiCache cache.t3.micro: ~$12
- ECS Fargate (0.25vCPU, 512MB): ~$10
- ALB: ~$20
- **총 ~$60/월**

### prod 환경 (월 예상)
- RDS db.t3.small: ~$30
- ElastiCache cache.t3.small: ~$24
- ECS Fargate (0.5vCPU, 1GB, 2개): ~$30
- ALB: ~$20
- **총 ~$110/월**

## 파일 설명

- `variables.tf`: 입력 변수 정의
- `main.tf`: Provider 설정
- `vpc.tf`: VPC 및 네트워크 설정
- `security.tf`: 보안 그룹 (방화벽)
- `s3.tf`: S3 버킷
- `rds.tf`: PostgreSQL 데이터베이스
- `elasticache.tf`: Redis
- `ecr.tf`: Docker 이미지 저장소
- `iam.tf`: IAM 역할 및 권한
- `alb.tf`: Load Balancer
- `ecs.tf`: ECS 클러스터 및 서비스
- `outputs.tf`: 출력값 정의

## 추가 정보

- Terraform 공식 문서: https://developer.hashicorp.com/terraform
- AWS Provider 문서: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
