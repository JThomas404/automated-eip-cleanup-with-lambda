data "aws_vpc" "boto3_eip_vpc" {
  id = var.vpc_id
}

resource "aws_security_group" "boto3_eip_sg" {
  vpc_id = data.aws_vpc.boto3_eip_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

data "aws_subnets" "boto3_eip_subnet" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.boto3_eip_vpc.id]
  }
}

