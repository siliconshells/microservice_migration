# Microservices Deployment on AWS
[![Build and Deploy Services](https://github.com/siliconshells/microservice_migration/actions/workflows/deploy.yml/badge.svg)](https://github.com/siliconshells/microservice_migration/actions/workflows/deploy.yml)  

## Architecture

### Overview
This project deploys two Flask microservices to AWS EC2 instances behind an Application Load Balancer with automated CI/CD via GitHub Actions.

### Architecture Diagram
```
                                    Internet
                                       |
                                       v
                            ┌──────────────────────┐
                            │  Application Load    │
                            │     Balancer         │
                            │   (Port 80)          │
                            └──────────┬───────────┘
                                       |
                    ┌──────────────────┴──────────────────┐
                    |                                      |
         /service1* |                           /service2* |
                    v                                      v
        ┌───────────────────┐              ┌───────────────────┐
        │  Target Group 1   │              │  Target Group 2   │
        │   (Port 8080)     │              │   (Port 8081)     │
        └─────────┬─────────┘              └─────────┬─────────┘
                  |                                   |
        ┌─────────┴─────────┐              ┌─────────┴─────────┐
        v                   v              v                   v
   ┌─────────┐         ┌─────────┐   ┌─────────┐         ┌─────────┐
   │  EC2-1  │         │  EC2-2  │   │  EC2-1  │         │  EC2-2  │
   │ Service1│         │ Service1│   │ Service2│         │ Service2│
   │  :8080  │         │  :8080  │   │  :8081  │         │  :8081  │
   └─────────┘         └─────────┘   └─────────┘         └─────────┘
        |                   |              |                   |
        └───────────────────┴──────────────┴───────────────────┘
                                   |
                          ┌────────v────────┐
                          │   Amazon ECR    │
                          │  (Docker Images)│
                          └─────────────────┘
```

### Components

**VPC Configuration:**
- Region: `us-east-1`
- 1 VPC with 2 public subnets (us-east-1a, us-east-1b)
- Internet Gateway for public access
- Security groups for ALB and EC2 instances

**Compute:**
- 2 EC2 t2.micro instances (Ubuntu 22.04 - Ubuntu 24.04 wasn't found in the region)
- Both instances in us-east-1a
- IAM instance profile with ECR read access
- Docker and Docker Compose installed

**Load Balancing:**
- Application Load Balancer (ALB)
- 2 Target Groups (service1-tg, service2-tg)
- Path-based routing:
  - `/service1*` → Service 1 (port 8080)
  - `/service2*` → Service 2 (port 8081)
- Health checks on `/health` endpoint

**Container Registry:**
- Amazon ECR repositories for service1 and service2
- Images tagged as `latest`

**Services:**
- Service 1: Flask app on port 8080 (internal: 5000)
- Service 2: Flask app on port 8081 (internal: 5001)
- Both include Prometheus metrics

## AWS Region
**us-east-1** (N. Virginia)

## Deployment Steps

### Prerequisites
1. AWS Account with appropriate permissions
2. AWS CLI configured locally
3. GitHub repository
4. EC2 key pair created in us-east-1

### 1. Configure GitHub Secrets
Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):
- `AWS_ACCESS_KEY_ID`: Your AWS access key
- `AWS_SECRET_ACCESS_KEY`: Your AWS secret key
- `AWS_ACCOUNT_ID`: Your AWS account ID
- `KEY_PAIR_NAME`: Name of your EC2 key pair
- `EC2_SSH_PRIVATE_KEY`: Content of your .pem file

### 2. Deploy Infrastructure
Push to the main branch or manually trigger the GitHub Actions workflow:

```bash
git add .
git commit -m "Deploy infrastructure"
git push origin main
```

The GitHub Actions workflow will automatically:
1. **Terraform Job:**
   - Import existing AWS resources (if any)
   - Create/update VPC, subnets, security groups
   - Launch EC2 instances with Docker installed
   - Create ALB with target groups and listener rules
   - Create ECR repositories

2. **Build-and-Push Job:**
   - Build Docker images for both services
   - Push images to Amazon ECR

3. **Deploy Job:**
   - Copy docker-compose.yml to EC2 instances
   - Pull images from ECR
   - Start services with docker-compose

### 3. Verify Deployment
After the workflow completes (approximately 8 minutes), get the ALB DNS name:

```bash
cd terraform
terraform output alb_dns_name
```

Or from AWS Console: EC2 → Load Balancers → services-alb → DNS name

## Running the Verification Script

### Install Dependencies
```bash
pip install requests
```

### Run Health Check
```bash
python verify_endpoints.py
```

### Expected Output
```
Testing endpoints for ALB: services-alb-1402427192.us-east-1.elb.amazonaws.com

http://services-alb-1402427192.us-east-1.elb.amazonaws.com/service1 - Status: 200
http://services-alb-1402427192.us-east-1.elb.amazonaws.com/service2 - Status: 200

Results: 2/2 endpoints healthy
```

### Exit Codes
- `0`: All endpoints healthy
- `1`: One or more endpoints failed

### Manual Testing
```bash
# Test service1
curl http://services-alb-1402427192.us-east-1.elb.amazonaws.com/service1

# Test service2
curl http://services-alb-1402427192.us-east-1.elb.amazonaws.com/service2
```

## Project Structure
```
.
├── .github/
│   └── workflows/
│       └── deploy.yml           # GitHub Actions CI/CD pipeline
├── servers/
│   ├── service1/
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── service1.py
│   ├── service2/
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── service2.py
│   └── docker-compose.yml       # Docker Compose configuration
├── terraform/
│   ├── main.tf                  # Infrastructure as Code
│   ├── variables.tf
│   ├── outputs.tf
│   ├── import-existing.sh       # Import existing resources
│   └── terraform.tfvars
├── verify_endpoints.py          # Health check script
├── screenshots                  # Folder with screenshots
└── README.md                    # This file
```

## Troubleshooting

### Services not responding
1. Check EC2 instances are running: `aws ec2 describe-instances --filters "Name=tag:Name,Values=service-instance-*"`
2. SSH into instance: `ssh -i your-key.pem ubuntu@<instance-ip>`
3. Check Docker containers: `sudo docker ps`
4. Check logs: `sudo docker-compose logs`

### ALB health checks failing
1. Verify target group health: AWS Console → EC2 → Target Groups
2. Check security group allows traffic from ALB to EC2 on ports 8080-8081
3. Verify services are listening: `curl localhost:8080` from EC2 instance

### GitHub Actions failing
1. Verify all GitHub secrets are set correctly
2. Check workflow logs in GitHub Actions tab
3. Ensure AWS credentials have necessary permissions

## Cleanup
To destroy all resources:
```bash
cd terraform
terraform destroy -var="key_pair_name=your-key-name"
```

Note: ECR repositories are protected from deletion and must be manually deleted if needed.

## Technologies Used
- **Infrastructure:** Terraform, AWS (VPC, EC2, ALB, ECR, IAM)
- **Containerization:** Docker, Docker Compose
- **CI/CD:** GitHub Actions
- **Application:** Python, Flask, Prometheus
- **Monitoring:** Prometheus metrics exposed on `/metrics`

## Cleanup confirmation
All AWS resources have been torn down.

## Screenshots In screenshots folder
- ECR Repository Images
- docker ps on both EC2 instances
- ALB DNS + curl responses

## Files in root repository
- verify_endpoints.py: Health check script
- docker-compose.yml: File used on EC2 instances
