data "archive_file" "lambda_package" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/../lambda/lambda_function.zip"
}

resource "aws_lambda_function" "ElasticIPCleanupLambda" {
  function_name    = var.lambda_function_name
  role             = aws_iam_role.boto3_eip_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  timeout          = 30

  tags = var.tags
}

resource "aws_iam_role" "boto3_eip_lambda_role" {
  name = "boto3-eip-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
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
        Sid    = "EC2ElasticIPAccess",
        Effect = "Allow",
        Action = [
          "ec2:DescribeAddresses",
          "ec2:ReleaseAddress"
        ],
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs",
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}
