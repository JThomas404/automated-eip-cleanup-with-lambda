# Automated Elastic IP Cleanup Using AWS Lambda and Terraform

## Table of Contents

- [Overview](#overview)
- [Real-World Business Value](#real-world-business-value)
- [Prerequisites](#prerequisites)
- [Project Folder Structure](#project-folder-structure)
- [Tasks and Implementation Steps](#tasks-and-implementation-steps)
- [Core Implementation Breakdown](#core-implementation-breakdown)
- [Local Testing and Debugging](#local-testing-and-debugging)
- [IAM Role and Permissions](#iam-role-and-permissions)
- [Design Decisions and Highlights](#design-decisions-and-highlights)
- [Skills Demonstrated](#skills-demonstrated)
- [Conclusion](#conclusion)

---

## Overview

This project implements an automated cost optimisation solution that identifies and releases unassociated Elastic IP addresses (EIPs) using AWS Lambda, EventBridge, and Terraform. The solution addresses the common enterprise challenge of EIP sprawl, where unused IP addresses accumulate over time, generating unnecessary AWS charges.

The architecture employs a serverless Lambda function triggered daily via EventBridge scheduling, scanning all VPC-scoped EIPs and releasing those without active associations. Infrastructure provisioning utilises Terraform for reproducible, version-controlled deployments with least-privilege IAM policies.

---

## Real-World Business Value

Elastic IPs represent a finite AWS resource with direct billing implications—AWS charges for any EIP not associated with a running EC2 instance. In enterprise environments with dynamic infrastructure provisioning, unassociated EIPs can accumulate rapidly, contributing to significant monthly cost overruns.

This automation solution delivers:
- **Cost Reduction**: Eliminates charges for idle EIPs (typically $0.005/hour per unassociated EIP)
- **Resource Governance**: Enforces infrastructure hygiene through automated cleanup
- **Operational Efficiency**: Reduces manual intervention in resource management
- **Compliance**: Supports cloud cost management policies and resource utilisation standards

---

## Prerequisites

- AWS CLI v2.x installed and configured with appropriate credentials
- Terraform v1.3+ with AWS Provider v5+
- Python 3.11 runtime environment
- IAM permissions for Lambda, EC2, EventBridge, and CloudWatch services
- Basic understanding of AWS VPC networking and Elastic IP concepts

---

## Project Folder Structure

```
automated-eip-cleanup-with-lambda-1/
├── lambda/
│   ├── event.json              # Test event payload for local debugging
│   ├── lambda_function.py      # Core Lambda function implementation
│   └── lambda_function.zip     # Packaged deployment artifact
├── scripts/
│   └── package-lambda.sh       # Automated packaging script
├── terraform/
│   ├── main.tf                 # Provider and backend configuration
│   ├── variables.tf            # Input variable definitions
│   ├── terraform.tfvars        # Environment-specific values
│   ├── vpc.tf                  # VPC and networking resources
│   ├── ec2.tf                  # EC2 instances and EIP associations
│   ├── lambda.tf               # Lambda function and IAM configuration
│   ├── eventbridge.tf          # EventBridge scheduling rules
│   └── outputs.tf              # Resource output definitions
├── requirements.txt            # Python dependencies
└── README.md
```

---

## Tasks and Implementation Steps

The implementation follows a systematic approach to infrastructure provisioning, code development, and automation configuration:

1. **Infrastructure Provisioning**: Terraform configuration creates test EIPs, EC2 instances, and VPC resources
2. **Lambda Development**: Python function implementation with Boto3 SDK integration
3. **Deployment Automation**: Shell scripting and Terraform archive data sources for packaging
4. **IAM Security Configuration**: Least-privilege role and policy definitions
5. **Event Scheduling**: EventBridge rule configuration for automated execution

---

## Core Implementation Breakdown

### Lambda Function Architecture

The core Lambda function utilises the Boto3 EC2 resource interface to enumerate and evaluate all VPC-scoped Elastic IP addresses:

```python
import boto3

def lambda_handler(event, context):
    ec2_resource = boto3.resource('ec2')
    released_count = 0

    for elastic_ip in ec2_resource.vpc_addresses.all():
        if elastic_ip.instance_id is None:
            try:
                print(f"Releasing unassociated EIP: {elastic_ip.public_ip} ({elastic_ip.allocation_id})")
                elastic_ip.release()
                released_count += 1
            except Exception as e:
                print(f"Error releasing EIP {elastic_ip.allocation_id}: {e}")

    return {
        'statusCode': 200,
        'body': f'Released {released_count} unassociated EIP(s).'
    }
```

**Key Implementation Features:**
- Resource-based Boto3 interface for simplified EIP management
- Comprehensive error handling to prevent execution failures
- Structured logging for operational visibility
- Atomic operations with individual EIP release attempts

### Terraform Infrastructure Configuration

The Terraform configuration employs modular resource definitions across multiple files:

**Lambda Function Definition** ([terraform/lambda.tf](terraform/lambda.tf)):
```hcl
resource "aws_lambda_function" "ElasticIPCleanupLambda" {
  function_name    = var.lambda_function_name
  role             = aws_iam_role.boto3_eip_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  timeout          = 30
  tags             = var.tags
}
```

**Automated Packaging** ([terraform/lambda.tf](terraform/lambda.tf)):
```hcl
data "archive_file" "lambda_package" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/../lambda/lambda_function.zip"
}
```

### EventBridge Scheduling Integration

Daily execution scheduling utilises EventBridge with explicit Lambda invocation permissions:

```hcl
resource "aws_cloudwatch_event_rule" "boto3_eip_cw_rule" {
  name                = "daily-eip-cleanup-rule"
  description         = "Triggers the Elastic IP Cleanup Lambda daily"
  schedule_expression = "rate(1 day)"
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ElasticIPCleanupLambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.boto3_eip_cw_rule.arn
}
```

---

## Local Testing and Debugging

Local development and testing employed multiple validation approaches:

**Manual Lambda Testing:**
```bash
# Package function locally
./scripts/package-lambda.sh

# Test with sample event payload
aws lambda invoke \
  --function-name ElasticIPCleanupLambda \
  --payload file://lambda/event.json \
  response.json
```

**EIP State Validation:**
```bash
# Verify EIP associations before execution
aws ec2 describe-addresses --query 'Addresses[?InstanceId==null]'

# Monitor CloudWatch logs during execution
aws logs tail /aws/lambda/ElasticIPCleanupLambda --follow
```

**Terraform State Verification:**
```bash
# Validate infrastructure state
terraform plan -detailed-exitcode
terraform apply -auto-approve

# Verify resource creation
terraform output
```

---

## IAM Role and Permissions

The implementation follows least-privilege security principles with precisely scoped IAM permissions:

```hcl
resource "aws_iam_role_policy" "boto3_eip_lambda_policy" {
  name = "boto3-eip-cleanup-policy"
  role = aws_iam_role.boto3_eip_lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["ec2:DescribeAddresses", "ec2:ReleaseAddress"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "*"
      }
    ]
  })
}
```

**Security Considerations:**
- Minimal EC2 permissions limited to address operations only
- CloudWatch logging permissions for operational visibility
- No broad administrative or cross-service access granted
- Role assumption restricted to Lambda service principal

---

## Design Decisions and Highlights

**Architecture Choices:**
- **Serverless Approach**: Lambda eliminates infrastructure management overhead whilst providing cost-effective execution for infrequent operations
- **Resource-Based Boto3 Interface**: Simplified EIP management compared to client-based approaches, reducing code complexity
- **EventBridge Scheduling**: Native AWS scheduling service provides reliable, managed cron functionality without external dependencies

**Terraform Implementation:**
- **Modular Configuration**: Separate files for logical resource groupings improve maintainability and code organisation
- **Automated Packaging**: `archive_file` data source eliminates manual deployment steps and ensures consistent artifact generation
- **Variable Parameterisation**: Configurable function names and tags support multi-environment deployments

**Operational Considerations:**
- **Error Isolation**: Individual EIP release attempts prevent single failures from affecting batch operations
- **Comprehensive Logging**: Structured output supports troubleshooting and audit requirements
- **Timeout Configuration**: 30-second timeout provides adequate execution time whilst preventing runaway processes

---

## Skills Demonstrated

**Cloud Architecture:**
- AWS Lambda serverless function design and implementation
- EventBridge event-driven architecture patterns
- VPC networking and Elastic IP resource management

**Infrastructure as Code:**
- Terraform resource provisioning and state management
- Modular configuration design and variable parameterisation
- Automated deployment pipeline integration

**Security Engineering:**
- IAM least-privilege policy design and implementation
- AWS service principal configuration and role assumption
- Resource-level access control and permission scoping

**Software Development:**
- Python development with AWS SDK (Boto3) integration
- Error handling and exception management patterns
- Structured logging and operational visibility implementation

**DevOps Practices:**
- Automated packaging and deployment scripting
- Infrastructure testing and validation procedures
- Version-controlled infrastructure management

---

## Conclusion

This project demonstrates practical application of AWS automation to address real-world cost optimisation challenges. The solution combines serverless computing, infrastructure as code, and event-driven architecture to deliver automated resource management with minimal operational overhead.

The implementation showcases enterprise-grade practices including least-privilege security, modular infrastructure design, and comprehensive error handling. The architecture provides a foundation for expanding into broader resource cleanup automation, including idle EBS volumes, untagged instances, and orphaned security groups.

Key technical achievements include seamless integration of multiple AWS services, robust error handling for production reliability, and maintainable Terraform configurations supporting multi-environment deployments.