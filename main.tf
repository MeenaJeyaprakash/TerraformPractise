terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
}

resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "MY-VPC"
  }
}

resource "aws_subnet" "pubsub" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "MY-VPC-PU-SUB"
  }
}

resource "aws_subnet" "prisub" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "MY-VPC-PRI-SUB"
  }
}

resource "aws_internet_gateway" "tigw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "MY-VPC-IGW"
  }
}

resource "aws_route_table" "pubrt" {
  vpc_id = aws_vpc.myvpc.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.tigw.id
    }
  

  tags = {
    Name = "MY-VPC-PUBRT"
  }
}

resource "aws_route_table_association" "pubrtasso" {
  subnet_id      = aws_subnet.pubsub.id
  route_table_id = aws_route_table.pubrt.id
}

resource "aws_eip" "myeip" {  
  vpc      = true
}

resource "aws_nat_gateway" "tnat" {
  allocation_id = aws_eip.myeip.id
  subnet_id     = aws_subnet.pubsub.id

  tags = {
    Name = "MY-VPC-NAT"
  }
}

resource "aws_route_table" "prirt" {
  vpc_id = aws_vpc.myvpc.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_nat_gateway.tnat.id
    }
  
  tags = {
    Name = "MY-VPC-PRIRT"
  }
}

resource "aws_route_table_association" "prirtasso" {
  subnet_id      = aws_subnet.prisub.id
  route_table_id = aws_route_table.prirt.id
}

resource "aws_security_group" "pubsg" {
  name        = "pubsg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
      description      = "TLS from VPC"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]      
    }
  ingress {
      description      = "TLS from VPC"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]      
    }
  
  egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]      
    }
  
  tags = {
    Name = "MY-VPC-PUB-SG"
  }
}

resource "aws_security_group" "prisg" {
  name        = "prisg"
  description = "Allow traffic only from public machine"
  vpc_id      = aws_vpc.myvpc.id

  ingress {   
      description      = "TLS from VPC"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      security_groups  = ["${aws_security_group.pubsg.id}"]   
    }
  ingress {
      description      = "TLS from VPC"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      security_groups  = ["${aws_security_group.pubsg.id}"]    
    }
  
  egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]      
    }
  
  tags = {
    Name = "MY-VPC-PRI-SG"
  }
}

resource "aws_instance" "Instance1" {
  ami                         = "ami-074cce78125f09d61"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.pubsub.id}"
  vpc_security_group_ids      = ["${aws_security_group.pubsg.id}"]
  key_name                    = "NewKeyEC"
  associate_public_ip_address = true
 
  tags = {
    Name = "My-Instance1"
  }
}
resource "aws_instance" "Instance2" {
  ami                         = "ami-074cce78125f09d61"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.prisub.id}"
  vpc_security_group_ids      = ["${aws_security_group.prisg.id}"]
  key_name                    = "NewKeyEC"

  tags = {
    Name = "My-Instance2"
  }
}