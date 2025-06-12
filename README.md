# Automated Elastic IP Cleanup Using AWS Lambda and Terraform

## Table of Contents

- [Scenario](#scenario)
- [Overview](#overview)
- [Real-World Use Case](#real-world-use-case)
- [Prerequisites](#prerequisites)
- [Project Folder Structure](#project-folder-structure)
- [Tasks Completed](#tasks-completed)

  - [1. Provisioning Resources](#1-provisioning-resources)
  - [2. Lambda Python Code](#2-lambda-python-code)
  - [3. Zipping the Lambda Code](#3-zipping-the-lambda-code)
  - [4. Lambda and IAM Configuration](#4-lambda-and-iam-configuration)
  - [5. Event Trigger with EventBridge](#5-event-trigger-with-eventbridge)

- [Code Snippet Breakdown for Hiring Managers](#code-snippet-breakdown-for-hiring-managers)
- [Conclusion](#conclusion)

---

## Scenario

A company frequently provisions Elastic IPs (EIPs) for its EC2 instances. However, over time, some of these EIPs remain unassociated, leading to unnecessary charges. The objective of this project is to automate the identification and release of unassociated Elastic IPs to optimize cost management and enforce infrastructure hygiene.

---

## Overview

This solution implements an automated cleanup process using an AWS Lambda function triggered daily by an Amazon EventBridge rule. The Lambda function scans all EIPs within the VPC scope and releases those that are unassociated. The entire infrastructure is defined using Terraform to ensure repeatable and version-controlled deployments.

---

## Real-World Use Case

Elastic IPs are a limited and billable AWS resource. AWS charges for any EIP that is not associated with a running EC2 instance. In large-scale environments with dynamic provisioning, EIPs can accumulate unintentionally, contributing to unnecessary monthly costs. This project provides a practical, automated approach to identify and release such idle IPs, enforcing best practices in cloud resource management.

---

## Prerequisites

- AWS CLI installed and configured
- IAM role with appropriate Lambda and EC2 permissions
- Python 3.11 environment (for local testing)
- Terraform v1.3+ and AWS provider v5+
- VSCode or any IDE with Python and Terraform support

---

## Project Folder Structure

```
├── lambda
│   ├── event.json
│   ├── lambda_function.py
│   └── lambda_function.zip
├── README.md
├── requirements.txt
├── scripts
│   └── package-lambda.sh
├── terraform
│   ├── ec2.tf
│   ├── eventbridge.tf
│   ├── lambda.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── terraform.tfstate
│   ├── terraform.tfstate.backup
│   ├── terraform.tfvars
│   ├── variables.tf
│   └── vpc.tf
└── venv
```

---

## Tasks Completed

Each component of this automation project was designed with operational efficiency, security, and maintainability in mind.

### 1. Provisioning Resources

Three Elastic IPs were created using Terraform. One EIP was associated with an EC2 instance to simulate real-world infrastructure. The remaining EIPs remain unassociated to demonstrate the cleanup mechanism.

```hcl
resource "aws_eip" "eip_1" {
  domain = "vpc"
  tags   = var.tags
}

resource "aws_instance" "boto3_eip_ec2" {
  ami             = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  subnet_id       = data.aws_subnet_ids.default.ids[0]
  security_groups = [aws_security_group.boto3_eip_sg.id]
  tags            = var.tags
}

resource "aws_eip_association" "boto3_eip_association" {
  instance_id   = aws_instance.boto3_eip_ec2.id
  allocation_id = aws_eip.eip_1.id
}
```

### 2. Lambda Python Code

The Lambda function, written in Python using Boto3, iterates over all Elastic IP addresses in the VPC. It checks whether each EIP is unassociated (i.e., not attached to an instance or network interface) and releases it. Logging is included for transparency, and errors are handled gracefully to avoid failed executions.

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

### 3. Zipping the Lambda Code

A shell script was developed to streamline the packaging of the Lambda function. This approach promotes automation and eliminates manual steps when updating code.

```bash
#!/bin/bash
set -e

echo "Zipping Lambda function..."
cd "$(dirname "$0")/../lambda" || exit 1
zip -r lambda_function.zip lambda_function.py > /dev/null
echo "Lambda function zipped as lambda/lambda_function.zip"
```

Alternatively, the `archive_file` data source in Terraform automates the packaging process during the provisioning stage:

```hcl
data "archive_file" "lambda_package" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/../lambda/lambda_function.zip"
}
```

### 4. Lambda and IAM Configuration

The Lambda function is defined in Terraform, and its execution role is restricted to only the necessary permissions. This demonstrates the principle of least privilege by limiting access to EC2 address operations and log streaming.

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

resource "aws_iam_role" "boto3_eip_lambda_role" {
  name = "boto3-eip-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

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

### 5. Event Trigger with EventBridge

Terraform provisions an EventBridge rule that invokes the Lambda function daily. Permissions are explicitly granted to allow EventBridge to trigger the Lambda.

```hcl
resource "aws_cloudwatch_event_rule" "boto3_eip_cw_rule" {
  name                = "daily-eip-cleanup-rule"
  description         = "Triggers the Elastic IP Cleanup Lambda daily"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "boto3_eip_cw_target" {
  rule      = aws_cloudwatch_event_rule.boto3_eip_cw_rule.name
  target_id = "eip-cleanup-target"
  arn       = aws_lambda_function.ElasticIPCleanupLambda.arn
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

## Conclusion

This project demonstrates the practical application of AWS automation to eliminate wasteful cloud spending. By integrating Lambda, Terraform, and EventBridge, the solution enforces cost controls and exemplifies scalable cloud operations. It follows infrastructure-as-code principles and security best practices, making it a strong portfolio piece for DevOps and Cloud Engineering roles.

It also lays a foundation for expanding into other resource cleanup tasks, such as idle volumes, untagged instances, or unattached security groups.

---
