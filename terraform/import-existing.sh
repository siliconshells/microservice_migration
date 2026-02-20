#!/bin/bash
set +e

# Import IAM
terraform import aws_iam_role.ec2_role ec2-ecr-role 2>/dev/null || true
terraform import aws_iam_instance_profile.ec2_profile ec2-ecr-profile 2>/dev/null || true

# Import ECR
terraform import aws_ecr_repository.service1 service1 2>/dev/null || true
terraform import aws_ecr_repository.service2 service2 2>/dev/null || true

# Import VPC resources
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=services-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
if [ "$VPC_ID" != "None" ] && [ ! -z "$VPC_ID" ]; then
  terraform import aws_vpc.main "$VPC_ID" 2>/dev/null || true
  
  SUBNET1=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=services-public-subnet" --query 'Subnets[0].SubnetId' --output text 2>/dev/null)
  [ "$SUBNET1" != "None" ] && [ ! -z "$SUBNET1" ] && terraform import aws_subnet.public "$SUBNET1" 2>/dev/null || true
  
  SUBNET2=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=services-public-subnet-2" --query 'Subnets[0].SubnetId' --output text 2>/dev/null)
  [ "$SUBNET2" != "None" ] && [ ! -z "$SUBNET2" ] && terraform import aws_subnet.public2 "$SUBNET2" 2>/dev/null || true
  
  IGW=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null)
  [ "$IGW" != "None" ] && [ ! -z "$IGW" ] && terraform import aws_internet_gateway.main "$IGW" 2>/dev/null || true
  
  RT=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=services-public-rt" --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null)
  [ "$RT" != "None" ] && [ ! -z "$RT" ] && terraform import aws_route_table.public "$RT" 2>/dev/null || true
  
  SG_EC2=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=ec2-services-sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
  [ "$SG_EC2" != "None" ] && [ ! -z "$SG_EC2" ] && terraform import aws_security_group.ec2 "$SG_EC2" 2>/dev/null || true
  
  SG_ALB=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=alb-sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
  [ "$SG_ALB" != "None" ] && [ ! -z "$SG_ALB" ] && terraform import aws_security_group.alb "$SG_ALB" 2>/dev/null || true
fi

# Import Target Groups first
TG1_ARN=$(aws elbv2 describe-target-groups --names service1-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
[ "$TG1_ARN" != "None" ] && [ ! -z "$TG1_ARN" ] && terraform import aws_lb_target_group.service1 "$TG1_ARN" 2>/dev/null || true

TG2_ARN=$(aws elbv2 describe-target-groups --names service2-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
[ "$TG2_ARN" != "None" ] && [ ! -z "$TG2_ARN" ] && terraform import aws_lb_target_group.service2 "$TG2_ARN" 2>/dev/null || true

# Import ALB and Listener
ALB_ARN=$(aws elbv2 describe-load-balancers --names services-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)
if [ "$ALB_ARN" != "None" ] && [ ! -z "$ALB_ARN" ]; then
  terraform import aws_lb.main "$ALB_ARN" 2>/dev/null || true
  
  LISTENER_ARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --query 'Listeners[0].ListenerArn' --output text 2>/dev/null)
  if [ "$LISTENER_ARN" != "None" ] && [ ! -z "$LISTENER_ARN" ]; then
    terraform import aws_lb_listener.http "$LISTENER_ARN" 2>/dev/null || true
    
    # Import listener rules
    RULES=$(aws elbv2 describe-rules --listener-arn "$LISTENER_ARN" --query 'Rules[?Priority!=`default`].[RuleArn,Priority]' --output text 2>/dev/null)
    while IFS=$'\t' read -r RULE_ARN PRIORITY; do
      if [ "$PRIORITY" = "100" ]; then
        terraform import aws_lb_listener_rule.service1 "$RULE_ARN" 2>/dev/null || true
      elif [ "$PRIORITY" = "200" ]; then
        terraform import aws_lb_listener_rule.service2 "$RULE_ARN" 2>/dev/null || true
      fi
    done <<< "$RULES"
  fi
fi

# Import EC2 instances
INST1=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=service-instance-1" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null)
[ "$INST1" != "None" ] && [ ! -z "$INST1" ] && terraform import aws_instance.service1 "$INST1" 2>/dev/null || true

INST2=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=service-instance-2" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null)
[ "$INST2" != "None" ] && [ ! -z "$INST2" ] && terraform import aws_instance.service2 "$INST2" 2>/dev/null || true

echo "Import complete"
set -e
