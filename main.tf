terraform {

#Initializing a bucket in s3 for the backend state store #

  backend "s3" {
    bucket = "alok-bucket12"
    key    = "assignment/terraform.tfstate"
    region = "us-east-1"
  }

#defining aws provider #

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.7.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

#defining vpc module which creates VPC resources on AWS #


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = var.vpc_cidr

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = [var.private_subnet_one_cidr, var.private_subnet_two_cidr]
  public_subnets  = [var.public_subnet_one_cidr, var.public_subnet_two_cidr]

  enable_nat_gateway = true
  enable_vpn_gateway = false
  single_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = "test"
  }
}

#below "http" block is defined to automatically grab my IP address # 

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

# aws_security_group resource block to create "Bastion_host_SG" #

resource aws_security_group "Bastion_host_SG" {
  name = "Bastion_host_SG"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]


  }
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]

  }
}


# aws_security_group resource block to create "Private_Instances_SG" #

resource aws_security_group "Private_Instances_SG" {
  name = "Private_Instances_SG"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]

  }
}

# aws_security_group resource block to create "Public_Web_SG" #


resource aws_security_group "Public_Web_SG" {
  name = "Public_Web_SG"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]

  }
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]

  }
}

# aws_instance resource block to create "bastion host "



resource "aws_instance" "bastion" {


  ami                    = "ami-04505e74c0741db8d"
  instance_type          = "t2.micro"
  key_name               = "EC2"
  monitoring             = true
  vpc_security_group_ids = ["${aws_security_group.Bastion_host_SG.id}"]
  subnet_id              = "${element(module.vpc.public_subnets,0)}"
  tags = {
    Terraform   = "true"
    Environment = "test"
    Name        = "bastion"
  }

}

# aws_instance resource block to create "app host"


resource "aws_instance" "app" {


  ami                    = "ami-04505e74c0741db8d"
  instance_type          = "t2.micro"
  key_name               = "EC2"
  monitoring             = true
  vpc_security_group_ids = ["${aws_security_group.Private_Instances_SG.id}"]
  subnet_id              = "${element(module.vpc.private_subnets,0)}"

  tags = {
    Terraform   = "true"
    Environment = "test"
    Name        = "app"
  }

}

# aws_instance resource block to create "jenkins host"

resource "aws_instance" "jenkins" {


  ami                    = "ami-04505e74c0741db8d"
  instance_type          = "t2.micro"
  key_name               = "EC2"
  monitoring             = true
  vpc_security_group_ids = ["${aws_security_group.Private_Instances_SG.id}"]
  subnet_id              = "${element(module.vpc.private_subnets,0)}"

  tags = {
    Terraform   = "true"
    Environment = "test"
    Name        = "jenkins"
  }

}

# aaws_lb_target_group resource block to create ALB target group having Jenkins host and it is named as "jenkins" #

resource "aws_lb_target_group" "test" {
  name     = "jenkins"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}

# aws_lb to Create an ALB #

resource "aws_lb" "test" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.Public_Web_SG.id}"]

  subnets            = ["${element(module.vpc.public_subnets,0)}","${element(module.vpc.public_subnets,1)}"]


  enable_deletion_protection = false


  tags = {
    Environment = "test"
  }
                            
}

# aws_lb_target_group resource block to create ALB target group having app host and it is named as "app" #


resource "aws_lb_target_group" "app" {
  name     = "app"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
}




