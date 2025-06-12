resource "aws_eip" "eip_1" {
  domain = "vpc"

  tags = var.tags
}

resource "aws_eip" "eip_2" {
  domain = "vpc"

  tags = var.tags
}

resource "aws_eip" "eip_3" {
  domain = "vpc"

  tags = var.tags
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

resource "aws_instance" "boto3_eip_ec2" {
  ami             = data.aws_ami.amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.boto3_eip_sg.id]
  subnet_id       = data.aws_subnets.boto3_eip_subnet.ids[0]

  tags = var.tags
}

resource "aws_eip_association" "boto3_eip_association" {
  instance_id   = aws_instance.boto3_eip_ec2.id
  allocation_id = aws_eip.eip_1.id
}
