#!/bin/bash
# Import existing resources into Terraform state

cd terraform

# Import IAM resources
terraform import aws_iam_role.ec2_role ec2-ecr-role 2>/dev/null || echo "IAM role already imported or doesn't exist"
terraform import aws_iam_instance_profile.ec2_profile ec2-ecr-profile 2>/dev/null || echo "Instance profile already imported or doesn't exist"

# Import ECR repositories
terraform import aws_ecr_repository.service1 service1 2>/dev/null || echo "ECR service1 already imported or doesn't exist"
terraform import aws_ecr_repository.service2 service2 2>/dev/null || echo "ECR service2 already imported or doesn't exist"

# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers --names services-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)
if [ "$ALB_ARN" != "None" ] && [ ! -z "$ALB_ARN" ]; then
  terraform import aws_lb.main "$ALB_ARN" 2>/dev/null || echo "ALB already imported"
fi

# Get Target Group ARNs
TG1_ARN=$(aws elbv2 describe-target-groups --names service1-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
if [ "$TG1_ARN" != "None" ] && [ ! -z "$TG1_ARN" ]; then
  terraform import aws_lb_target_group.service1 "$TG1_ARN" 2>/dev/null || echo "TG1 already imported"
fi

TG2_ARN=$(aws elbv2 describe-target-groups --names service2-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
if [ "$TG2_ARN" != "None" ] && [ ! -z "$TG2_ARN" ]; then
  terraform import aws_lb_target_group.service2 "$TG2_ARN" 2>/dev/null || echo "TG2 already imported"
fi

echo "Import complete. Run 'terraform plan' to verify."
