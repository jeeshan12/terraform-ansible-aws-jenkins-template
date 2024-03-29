resource "aws_instance" "jenkins-master" {
  provider                    = aws.region-master
  instance_type               = var.instance-type
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins-sg.id]
  subnet_id                   = aws_subnet.subet-1-master.id
}

