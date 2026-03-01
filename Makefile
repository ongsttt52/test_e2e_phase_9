.PHONY: help init setup-secrets dev destroy-aws-manual

PROJECT_NAME = test_e2e_phase_9
PROJECT_NAME_NORMALIZED = $(shell echo test_e2e_phase_9 | tr '_' '-')
AWS_REGION = ap-northeast-2
TF_STATE_BUCKET = test-e2e-phase-9-state-bucket

help:
	@echo ""
	@echo "test-e2e-phase-9 - Available Commands"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  make init               - Create GitHub repo & initial deployment"
	@echo "  make setup-secrets      - Setup GitHub Secrets"
	@echo "  make dev                - Start local development"
	@echo "  make destroy-aws-manual - (Emergency) Manual AWS resource cleanup"
	@echo ""
	@echo "💡 Tip: Use GitHub Actions 'Destroy AWS Infrastructure' workflow instead"
	@echo ""

init:
	@echo ""
	@echo "🚀 Initializing GitHub Repository..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "🔍 Checking .env file..."
	@if [ ! -f .env ]; then \
		echo ""; \
		echo "❌ .env file not found!"; \
		echo ""; \
		echo "Please create .env file first:"; \
		echo "  1. cp .env.example .env"; \
		echo "  2. Edit .env and add your AWS credentials"; \
		echo ""; \
		echo "Required in .env:"; \
		echo "  - AWS_ACCESS_KEY_ID"; \
		echo "  - AWS_SECRET_ACCESS_KEY"; \
		echo ""; \
		echo "Then run: make init"; \
		exit 1; \
	fi
	@. ./.env && \
	if [ -z "$$AWS_ACCESS_KEY_ID" ] || [ -z "$$AWS_SECRET_ACCESS_KEY" ]; then \
		echo ""; \
		echo "❌ AWS credentials not found in .env!"; \
		echo ""; \
		echo "Please add to .env:"; \
		echo "  AWS_ACCESS_KEY_ID=your-key"; \
		echo "  AWS_SECRET_ACCESS_KEY=your-secret"; \
		echo ""; \
		exit 1; \
	fi
	@echo "✓ .env file found with AWS credentials"
	@echo ""
	@if [ ! -d .git ]; then \
		echo "📦 Initializing git..."; \
		git init; \
		git add .; \
		git commit -m "Initial commit: Django AWS project"; \
	fi
	@echo ""
	@echo "Checking GitHub CLI..."
	@if ! gh auth status >/dev/null 2>&1; then \
		echo "❌ Please login to GitHub CLI first:"; \
		echo "   gh auth login"; \
		exit 1; \
	fi
	@echo "✓ GitHub CLI authenticated"
	@echo ""
	@read -p "GitHub repository name [$(PROJECT_NAME)]: " REPO_NAME; \
	REPO_NAME=$${REPO_NAME:-$(PROJECT_NAME)}; \
	read -p "Use organization? (y/N): " USE_ORG; \
	if [ "$$USE_ORG" = "y" ] || [ "$$USE_ORG" = "Y" ]; then \
		read -p "Organization name: " ORG_NAME; \
		REPO_NAME="$$ORG_NAME/$$REPO_NAME"; \
	fi; \
	read -p "Private repository? (y/N): " IS_PRIVATE; \
	echo ""; \
	echo "📝 Creating GitHub repository: $$REPO_NAME"; \
	if [ "$$IS_PRIVATE" = "y" ] || [ "$$IS_PRIVATE" = "Y" ]; then \
		gh repo create $$REPO_NAME --private --source=. --remote=origin; \
	else \
		gh repo create $$REPO_NAME --public --source=. --remote=origin; \
	fi
	@echo ""
	@echo "✅ Repository created!"
	@echo ""
	@echo "🔐 Setting up GitHub Secrets..."
	@echo ""
	@. ./.env && \
	AWS_ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo ""); \
	if [ -z "$$AWS_ACCOUNT_ID" ]; then \
		echo "⚠️  Could not auto-detect AWS Account ID"; \
		read -p "AWS Account ID: " AWS_ACCOUNT_ID; \
	else \
		echo "✓ AWS Account ID: $$AWS_ACCOUNT_ID"; \
	fi; \
	read -sp "Database Password (default: postgres): " DB_PASS; \
	DB_PASS=$${DB_PASS:-postgres}; \
	echo ""; \
	echo ""; \
	echo "Setting secrets..."; \
	gh secret set AWS_ACCESS_KEY_ID --body "$$AWS_ACCESS_KEY_ID" && \
	gh secret set AWS_SECRET_ACCESS_KEY --body "$$AWS_SECRET_ACCESS_KEY" && \
	gh secret set AWS_ACCOUNT_ID --body "$$AWS_ACCOUNT_ID" && \
	gh secret set DB_PASSWORD --body "$$DB_PASS" && \
	DJANGO_SECRET_KEY=$$(python3 -c "import secrets; print(secrets.token_urlsafe(50))") && \
	gh secret set DJANGO_SECRET_KEY --body "$$DJANGO_SECRET_KEY" && \
	echo "  ✓ DJANGO_SECRET_KEY auto-generated"; \
	read -sp "Django Superuser Password (default: admin1234): " SU_PASS; \
	SU_PASS=$${SU_PASS:-admin1234}; \
	echo ""; \
	gh secret set DJANGO_SUPERUSER_PASSWORD --body "$$SU_PASS" && \
	echo "  ✓ DJANGO_SUPERUSER_PASSWORD set"

	@echo ""
	@echo "🔑 Generating EC2 SSH key pair..."
	@KEY_PATH=~/.ssh/$(PROJECT_NAME_NORMALIZED)-ec2-key; \
	if [ ! -f "$$KEY_PATH" ]; then \
		ssh-keygen -t ed25519 -f "$$KEY_PATH" -N "" -C "$(PROJECT_NAME)-ec2"; \
		echo "  ✓ SSH key generated: $$KEY_PATH"; \
	else \
		echo "  ✓ SSH key already exists: $$KEY_PATH"; \
	fi; \
	gh secret set EC2_SSH_PRIVATE_KEY < "$$KEY_PATH" && \
	gh secret set EC2_SSH_PUBLIC_KEY --body "$$(cat $$KEY_PATH.pub)" && \
	echo "  ✓ SSH keys saved to GitHub Secrets"

	@echo ""
	@echo "✅ Secrets configured!"
	@echo ""
	@echo "🌿 Creating dev branch (local only)..."
	@git checkout -b dev
	@git checkout main
	@echo "✓ dev branch created for local development"
	@echo ""
	@echo "🚀 Pushing main branch to GitHub..."
	@git push origin main
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "✅ Repository initialized!"
	@echo ""
	@echo "📋 Branch structure:"
	@echo "  - main: AWS demo deployment (auto-deploy on push)"
	@echo "  - dev:  Local development only (docker-compose)"
	@echo ""
	@echo "🔗 Links:"
	@echo "  Repository: https://github.com/$$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
	@echo "  Actions:    https://github.com/$$(gh repo view --json nameWithOwner --jq .nameWithOwner)/actions"
	@echo ""
	@echo "📝 Next steps:"
	@echo "  1. Go to GitHub Actions tab"
	@echo "  2. Run 'Create AWS Infrastructure' workflow (one-time setup)"
	@echo "  3. After infrastructure is created:"
	@echo "     - Push to main → auto-deploy to AWS ✅"
	@echo "     - Work on dev → local development only 💻"
	@echo ""
	@echo "💡 Local development:"
	@echo "  git checkout dev"
	@echo "  make dev"
	@echo ""

setup-secrets:
	@echo ""
	@echo "🔐 Setting up GitHub Secrets..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@if [ ! -f .env ]; then \
		echo "❌ .env file not found!"; \
		echo ""; \
		echo "Please create .env file first:"; \
		echo "  cp .env.example .env"; \
		echo "  # Edit .env with your AWS credentials"; \
		echo ""; \
		exit 1; \
	fi
	@echo "📖 Reading from .env file..."
	@echo ""
	@. ./.env && \
	if [ -z "$$AWS_ACCESS_KEY_ID" ] || [ -z "$$AWS_SECRET_ACCESS_KEY" ]; then \
		echo "❌ AWS credentials not found in .env file!"; \
		echo "Please add AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to .env"; \
		exit 1; \
	fi; \
	AWS_ACCOUNT_ID=$$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo ""); \
	if [ -z "$$AWS_ACCOUNT_ID" ]; then \
		echo "⚠️  Could not auto-detect AWS Account ID"; \
		read -p "AWS Account ID: " AWS_ACCOUNT_ID; \
	else \
		echo "✓ AWS Account ID: $$AWS_ACCOUNT_ID"; \
	fi; \
	read -sp "Database Password (default: postgres): " DB_PASS; \
	DB_PASS=$${DB_PASS:-postgres}; \
	echo ""; \
	echo ""; \
	echo "Setting secrets..."; \
	gh secret set AWS_ACCESS_KEY_ID --body "$$AWS_ACCESS_KEY_ID" && \
	gh secret set AWS_SECRET_ACCESS_KEY --body "$$AWS_SECRET_ACCESS_KEY" && \
	gh secret set AWS_ACCOUNT_ID --body "$$AWS_ACCOUNT_ID" && \
	gh secret set DB_PASSWORD --body "$$DB_PASS" && \
	DJANGO_SECRET_KEY=$$(python3 -c "import secrets; print(secrets.token_urlsafe(50))") && \
	gh secret set DJANGO_SECRET_KEY --body "$$DJANGO_SECRET_KEY" && \
	echo "  ✓ DJANGO_SECRET_KEY auto-generated"; \
	read -sp "Django Superuser Password (default: admin1234): " SU_PASS; \
	SU_PASS=$${SU_PASS:-admin1234}; \
	echo ""; \
	gh secret set DJANGO_SUPERUSER_PASSWORD --body "$$SU_PASS" && \
	echo "  ✓ DJANGO_SUPERUSER_PASSWORD set"
	@echo ""
	@echo "✅ Secrets configured!"
	@echo ""
	@echo "Now push to trigger deployment:"
	@echo "  git push origin main"
	@echo ""

dev:
	@echo ""
	@echo "🚀 Starting Local Development..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@if [ ! -f .env ]; then \
		echo "⚠️  .env file not found. Copying from .env.example..."; \
		cp .env.example .env; \
		echo ""; \
		echo "❌ Please edit .env file with your AWS credentials!"; \
		echo "   Required: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"; \
		exit 1; \
	fi
	@echo "🐳 Starting Docker Compose..."
	@docker compose up -d
	@echo ""
	@echo "✅ Services started!"
	@echo ""
	@echo "Access at:"
	@echo "  Backend API:  http://localhost:8000/api/"
	@echo "  Admin Panel:  http://localhost:8000/api/admin/"
	@echo "  API Docs:     http://localhost:8000/api/docs/"
	@echo "  WebSocket:    ws://localhost:8001"
	@echo ""
	@echo "Useful commands:"
	@echo "  View logs:       docker compose logs -f"
	@echo "  Stop services:   docker compose down"
	@echo "  Run migrations:  docker compose exec backend uv run python manage.py migrate"
	@echo "  Create superuser: docker compose exec backend uv run python manage.py createsuperuser"
	@echo ""

destroy-aws-manual:
	@echo ""
	@echo "⚠️  Manual AWS Resource Deletion (Emergency Only)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "⚠️  WARNING: Use GitHub Actions 'Destroy AWS Infrastructure' workflow instead!"
	@echo "   This manual cleanup is only for emergencies (e.g., Terraform state issues)"
	@echo ""
	@echo "⚠️  This will DELETE ALL AWS resources!"
	@echo ""
	@echo "Resources to be deleted:"
	@echo "  - ECS Cluster & Service"
	@echo "  - RDS Database"
	@echo "  - ElastiCache Redis"
	@echo "  - S3 Bucket (with all files)"
	@echo "  - ECR Repository (with all images)"
	@echo "  - VPC & Networking"
	@echo "  - IAM Roles"
	@echo ""
	@if [ ! -f .env ]; then \
		echo "❌ .env file not found!"; \
		echo "Please create .env with AWS credentials first."; \
		exit 1; \
	fi
	@read -p "Type 'destroy demo' to confirm deletion: " CONFIRM; \
	if [ "$$CONFIRM" != "destroy demo" ]; then \
		echo ""; \
		echo "❌ Deletion cancelled."; \
		exit 1; \
	fi
	@echo ""
	@echo "🗑️  Starting deletion..."
	@echo ""
	@. ./.env && \
	PROJECT_SLUG=$(PROJECT_NAME_NORMALIZED); \
	REGION=$(AWS_REGION); \
	\

	echo "1️⃣  Terminating EC2 Instance..."; \
	INSTANCE_ID=$$(aws ec2 describe-instances \
		--filters "Name=tag:Name,Values=$${PROJECT_SLUG}-ec2-demo" \
				  "Name=instance-state-name,Values=running,stopped" \
		--query 'Reservations[0].Instances[0].InstanceId' \
		--output text --region $$REGION 2>/dev/null); \
	if [ "$$INSTANCE_ID" != "None" ] && [ -n "$$INSTANCE_ID" ]; then \
		aws ec2 terminate-instances --instance-ids $$INSTANCE_ID --region $$REGION 2>/dev/null; \
		echo "  ✓ EC2 instance terminating: $$INSTANCE_ID"; \
		echo "  Waiting for termination..."; \
		aws ec2 wait instance-terminated --instance-ids $$INSTANCE_ID --region $$REGION 2>/dev/null || true; \
	else \
		echo "  ⚠️  EC2 instance not found"; \
	fi; \
	echo ""; \
	\
	echo "2️⃣  Releasing Elastic IP..."; \
	EIP_ALLOC=$$(aws ec2 describe-addresses \
		--filters "Name=tag:Name,Values=$${PROJECT_SLUG}-eip-demo" \
		--query 'Addresses[0].AllocationId' \
		--output text --region $$REGION 2>/dev/null); \
	if [ "$$EIP_ALLOC" != "None" ] && [ -n "$$EIP_ALLOC" ]; then \
		aws ec2 release-address --allocation-id $$EIP_ALLOC --region $$REGION 2>/dev/null; \
		echo "  ✓ Elastic IP released"; \
	else \
		echo "  ⚠️  Elastic IP not found"; \
	fi; \
	echo ""; \
	\
	echo "3️⃣  Deleting EC2 Key Pair..."; \
	aws ec2 delete-key-pair --key-name $${PROJECT_SLUG}-ec2-key-demo --region $$REGION 2>/dev/null \
		|| echo "  ⚠️  Key pair not found"; \
	echo ""; \
	\
	echo "4️⃣  Deleting IAM Instance Profile..."; \
	aws iam remove-role-from-instance-profile \
		--instance-profile-name $${PROJECT_SLUG}-ec2-profile-demo \
		--role-name $${PROJECT_SLUG}-ec2-role-demo 2>/dev/null || true; \
	aws iam delete-instance-profile \
		--instance-profile-name $${PROJECT_SLUG}-ec2-profile-demo 2>/dev/null \
		|| echo "  ⚠️  Instance profile not found"; \
	echo ""; \
	\
	echo "5️⃣  Deleting EC2 IAM Role..."; \
	INLINE_POLICIES=$$(aws iam list-role-policies \
		--role-name $${PROJECT_SLUG}-ec2-role-demo \
		--query 'PolicyNames[]' --output text 2>/dev/null); \
	for policy in $$INLINE_POLICIES; do \
		aws iam delete-role-policy --role-name $${PROJECT_SLUG}-ec2-role-demo --policy-name $$policy 2>/dev/null; \
	done; \
	aws iam delete-role --role-name $${PROJECT_SLUG}-ec2-role-demo 2>/dev/null \
		|| echo "  ⚠️  EC2 IAM role not found"; \
	echo "";


	@. ./.env && \
	PROJECT_SLUG=$(PROJECT_NAME_NORMALIZED); \
	REGION=$(AWS_REGION); \
	\
	echo "Deleting S3 Bucket..."; \
	aws s3 rb s3://$${PROJECT_SLUG}-media-bucket \
		--force \
		--region $$REGION 2>/dev/null || echo "  ⚠️  S3 Bucket not found"; \
	echo ""; \
	\
	echo "Deleting CloudWatch Log Groups..."; \
	aws logs delete-log-group \
		--log-group-name /ecs/$${PROJECT_SLUG}-backend-demo \
		--region $$REGION 2>/dev/null || true; \
	aws logs delete-log-group \
		--log-group-name /ecs/$${PROJECT_SLUG}-frontend-demo \
		--region $$REGION 2>/dev/null || true; \
	aws logs delete-log-group \
		--log-group-name /ec2/$${PROJECT_SLUG}-demo \
		--region $$REGION 2>/dev/null || true; \
	echo ""; \
	\
	echo "Deleting Security Groups..."; \
	VPC_ID=$$(aws ec2 describe-vpcs \
		--filters "Name=tag:Name,Values=$${PROJECT_SLUG}-vpc-demo" \
		--region $$REGION \
		--query 'Vpcs[0].VpcId' \
		--output text 2>/dev/null); \
	if [ "$$VPC_ID" != "None" ] && [ -n "$$VPC_ID" ]; then \
		SG_IDS=$$(aws ec2 describe-security-groups \
			--filters "Name=vpc-id,Values=$$VPC_ID" \
			--region $$REGION \
			--query 'SecurityGroups[?GroupName!=`default`].GroupId' \
			--output text 2>/dev/null); \
		for sg_id in $$SG_IDS; do \
			aws ec2 delete-security-group \
				--group-id $$sg_id \
				--region $$REGION 2>/dev/null; \
		done; \
	fi; \
	echo ""; \
	\
	echo "1️⃣3️⃣  Deleting Subnets..."; \
	if [ "$$VPC_ID" != "None" ] && [ -n "$$VPC_ID" ]; then \
		SUBNET_IDS=$$(aws ec2 describe-subnets \
			--filters "Name=vpc-id,Values=$$VPC_ID" \
			--region $$REGION \
			--query 'Subnets[].SubnetId' \
			--output text 2>/dev/null); \
		for subnet_id in $$SUBNET_IDS; do \
			aws ec2 delete-subnet \
				--subnet-id $$subnet_id \
				--region $$REGION 2>/dev/null; \
		done; \
	fi; \
	echo ""; \
	\
	echo "1️⃣4️⃣  Deleting Internet Gateway..."; \
	if [ "$$VPC_ID" != "None" ] && [ -n "$$VPC_ID" ]; then \
		IGW_ID=$$(aws ec2 describe-internet-gateways \
			--filters "Name=attachment.vpc-id,Values=$$VPC_ID" \
			--region $$REGION \
			--query 'InternetGateways[0].InternetGatewayId' \
			--output text 2>/dev/null); \
		if [ "$$IGW_ID" != "None" ] && [ -n "$$IGW_ID" ]; then \
			aws ec2 detach-internet-gateway \
				--internet-gateway-id $$IGW_ID \
				--vpc-id $$VPC_ID \
				--region $$REGION 2>/dev/null; \
			aws ec2 delete-internet-gateway \
				--internet-gateway-id $$IGW_ID \
				--region $$REGION 2>/dev/null; \
		fi; \
	fi; \
	echo ""; \
	\
	echo "1️⃣5️⃣  Deleting Route Tables..."; \
	if [ "$$VPC_ID" != "None" ] && [ -n "$$VPC_ID" ]; then \
		RT_IDS=$$(aws ec2 describe-route-tables \
			--filters "Name=vpc-id,Values=$$VPC_ID" \
			--region $$REGION \
			--query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
			--output text 2>/dev/null); \
		for rt_id in $$RT_IDS; do \
			aws ec2 delete-route-table \
				--route-table-id $$rt_id \
				--region $$REGION 2>/dev/null; \
		done; \
	fi; \
	echo ""; \
	\
	echo "1️⃣6️⃣  Deleting VPC..."; \
	if [ "$$VPC_ID" != "None" ] && [ -n "$$VPC_ID" ]; then \
		aws ec2 delete-vpc \
			--vpc-id $$VPC_ID \
			--region $$REGION 2>/dev/null || echo "  ⚠️  VPC deletion failed (may need manual cleanup)"; \
	fi; \
	echo ""; \
	\

	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "✅ AWS resources deletion completed!"
	@echo ""
	@echo "⚠️  Note: Some resource deletions may still be in progress."
	@echo "   Check AWS Console to verify all resources are deleted."
	@echo ""
	@echo "Terraform state bucket: $(TF_STATE_BUCKET)"
	@read -p "Also delete Terraform state bucket? (yes/no) [no]: " DEL_STATE; \
	if [ "$$DEL_STATE" = "yes" ]; then \
		echo ""; \
		echo "🗑️  Deleting state bucket: $(TF_STATE_BUCKET)"; \
		echo "  Removing all object versions..."; \
		aws s3api list-object-versions \
			--bucket $(TF_STATE_BUCKET) \
			--query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
			--output json 2>/dev/null | \
		python3 -c "\
import sys, json; \
data = json.load(sys.stdin); \
objects = data.get('Objects') or []; \
[print(json.dumps({'Objects': objects[i:i+1000], 'Quiet': True})) for i in range(0, len(objects), 1000)]" | \
		while read -r payload; do \
			aws s3api delete-objects --bucket $(TF_STATE_BUCKET) --delete "$$payload" 2>/dev/null || true; \
		done; \
		echo "  Removing all delete markers..."; \
		aws s3api list-object-versions \
			--bucket $(TF_STATE_BUCKET) \
			--query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
			--output json 2>/dev/null | \
		python3 -c "\
import sys, json; \
data = json.load(sys.stdin); \
objects = data.get('Objects') or []; \
[print(json.dumps({'Objects': objects[i:i+1000], 'Quiet': True})) for i in range(0, len(objects), 1000)]" | \
		while read -r payload; do \
			aws s3api delete-objects --bucket $(TF_STATE_BUCKET) --delete "$$payload" 2>/dev/null || true; \
		done; \
		aws s3api delete-bucket --bucket $(TF_STATE_BUCKET) 2>/dev/null \
			&& echo "  ✅ State bucket deleted" \
			|| echo "  ⚠️  State bucket deletion failed"; \
	else \
		echo "  ℹ️  State bucket preserved: $(TF_STATE_BUCKET)"; \
	fi
	@echo ""
	@echo "To verify deletion:"
	@echo "  aws resourcegroupstaggingapi get-resources --region $(AWS_REGION)"
	@echo ""

.DEFAULT_GOAL := help
