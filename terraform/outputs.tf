output "vpc_id" {
  value = data.aws_vpc.boto3_eip_vpc.id
}

output "eip_1_public_ip" {
  value = aws_eip.eip_1.public_ip
}

output "eip_2_public_ip" {
  value = aws_eip.eip_2.public_ip
}

output "eip_3_public_ip" {
  value = aws_eip.eip_3.public_ip
}
