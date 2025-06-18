
output "private_ip_NodeA" {
  value = aws_instance.ec2_NodeA.private_ip
  description = "value of private IP address of EC2 instance in Subnet_A"
}

output "private_ip_NodeB" {
  value = aws_instance.ec2_NodeB.private_ip
  description = "value of private IP address of EC2 instance in Subnet_B"
}       