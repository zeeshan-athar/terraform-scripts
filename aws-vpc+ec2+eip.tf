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

# create route table association
resource "aws_route_table_association" "zee-rta" {
  subnet_id = aws_subnet.zee-subnet.id
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

#create network interface
resource "aws_network_interface" "zee-nic" {
  subnet_id = aws_subnet.zee-subnet.id
  private_ips = ["10.0.1.40"]
  security_groups = [aws_security_group.zee-sg.id]

  tags = {
    "Name" = "zee-nic"
  }
}

#create instance
resource "aws_instance" "zee-e2" {
  ami = "ami-0ddf424f81ddb0720"
  instance_type = "t2.micro"
  availability_zone = "us-west-2a"
  key_name = "zee-key"

  network_interface {
    network_interface_id = aws_network_interface.zee-nic.id
    device_index = 0
  }

  user_data = <<EOF
  #!/usr/bin/bash
  sudo apt update
  sudo apt install apache2 -y
  sudo systemctl start apache2
  sudo bash -c 'echo \<html\>\<head\>\<title\>Terraform\</title\>\</head\>\<body\>\<h2\>Deployed through terraform\</h2\>\</body\>\</html\> > /var/www/html/index.html'
  EOF

  tags = {
    "Name" = "zee-webserver"
  }
}

#create elastic IP
resource "aws_eip" "zee-eip" {
  instance = aws_instance.zee-e2.id
  vpc = true 
  associate_with_private_ip = "10.0.1.40"
  depends_on = [aws_internet_gateway.zee-igw]

  tags = {
    "Name" = "zee-EIP"
  }
}
