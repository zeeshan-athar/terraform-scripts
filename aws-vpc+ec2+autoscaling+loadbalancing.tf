provider "aws" {
  profile = "default"
  region = "us-west-2"
}

# Create VPC
resource "aws_vpc" "zee-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "Name" = "zee-vpc"
  }
}

# create internet gateway
resource "aws_internet_gateway" "zee-igw" {
  vpc_id = aws_vpc.zee-vpc.id

  tags = {
    "Name" = "zee-igw"
  }
}

# create subnet
resource "aws_subnet" "zee-subnet" {
  vpc_id = aws_vpc.zee-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2a"

  tags = {
    "Name" = "zee-subnet-public"
  }
}

#create subnet 2
resource "aws_subnet" "zee-subnet2" {
  vpc_id = aws_vpc.zee-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-2b"

  tags = {
    "Name" = "zee-subnet2-public"
  }
}

# create route table
resource "aws_route_table" "zee-rt" {
  vpc_id = aws_vpc.zee-vpc.id
  depends_on = [
    aws_internet_gateway.zee-igw
  ]

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.zee-igw.id
  }

  tags = {
    "Name" = "zee-rt"
  }
}

# create route table association for subnet1
resource "aws_route_table_association" "zee-rta" {
  subnet_id = aws_subnet.zee-subnet.id
  route_table_id = aws_route_table.zee-rt.id
}

# create route table association for subnet2
resource "aws_route_table_association" "zee-rta2" {
  subnet_id = aws_subnet.zee-subnet2.id
  route_table_id = aws_route_table.zee-rt.id
}

#create security group
resource "aws_security_group" "zee-sg" {
  name = "zee-sg"
  description = "Security group for webserver."
  vpc_id = aws_vpc.zee-vpc.id

  ingress  {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH"
    from_port = 22
    protocol = "tcp"
    to_port = 22
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow http"
    from_port = 80
    protocol = "tcp"
    to_port = 80
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "zee-sg"
  }
}

#create launch configuration
resource "aws_launch_configuration" "zee-lc" {
  name = "zee-lc1"
  image_id = "ami-0d70546e43a941d70"
  instance_type = "t2.micro"
  key_name = "zee-key"
  associate_public_ip_address = true
  security_groups = [aws_security_group.zee-sg.id]
  user_data = <<-EOF
  #!/usr/bin/bash
  sudo apt update
  sudo apt install apache2 -y
  sudo systemctl start apache2
  sudo bash -c 'echo \<html\>\<head\>\<title\>Terraform\</title\>\</head\>\<body\>\<h2\>Deployed through terraform\</h2\>\</body\>\</html\> > /var/www/html/index.html'
  EOF

  lifecycle {
    create_before_destroy = true
  }
}

#create autoscaling group
resource "aws_autoscaling_group" "zee-asg" {
  name = "zee-asg"
  launch_configuration = aws_launch_configuration.zee-lc.name
  min_size = 1
  max_size = 2
  desired_capacity = 1
  target_group_arns = [aws_lb_target_group.zee-tg.arn]
  vpc_zone_identifier = [aws_subnet.zee-subnet.id,aws_subnet.zee-subnet2.id]
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup = 300
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

#create autoscaling policy
resource "aws_autoscaling_policy" "zee-asp" {
  name = "zee-asp"
  adjustment_type = "ChangeInCapacity"
  policy_type = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.zee-asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# create application load balancer
resource "aws_lb" "zee-alb" {
  name = "zee-alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.zee-sg.id]
  subnets = [aws_subnet.zee-subnet.id,aws_subnet.zee-subnet2.id]
}

# create target group
resource "aws_lb_target_group" "zee-tg" {
  name = "zee-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.zee-vpc.id
}

#create target group attachment
resource "aws_autoscaling_attachment" "zee-asa" {
  autoscaling_group_name = aws_autoscaling_group.zee-asg.id
  lb_target_group_arn = aws_lb_target_group.zee-tg.arn
}


#create alb listner
resource "aws_lb_listener" "zee-alb-listner" {
  load_balancer_arn = aws_lb.zee-alb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.zee-tg.arn
  }
}
