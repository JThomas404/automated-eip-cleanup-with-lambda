variable "aws_region" {
  description = "Default AWS region for the project resources."
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    Project     = "boto3-eip-script"
    Environment = "Dev"
  }
}

variable "vpc_id" {
  description = "ID of the VPC to deploy into."
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda Function."
  type        = string
  default     = "boto3-eip-cleanup"
}

