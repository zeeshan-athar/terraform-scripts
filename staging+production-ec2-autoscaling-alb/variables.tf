variable "region" {
  description = "AWS Region"
  type = string
  default = "webserver"
}

variable "prefix" {
  description = "Name of Infrastructure"
  type = string
  default = "webserver"
}

variable "vpc-cidrblock" {
  description = "cidr block for vpc"
  type = string
  default = "10.0.0.0/16"
}

variable "public-subnet1-cidrblock" {
  description = "cidr block for subnet 1"
  type = string
  default = "10.0.1.0/24"
}

variable "public-subnet2-cidrblock" {
  description = "cidr block for subnet 2"
  type = string
  default = "10.0.2.0/24"
}

variable "ec2-ami-id" {
  description = "EC2 image id"
  type = string
  default = "ami-0d70546e43a941d70"
}

variable "ec2-instance-type" {
  description = "Type of EC2 instance"
  type = string
  default = "t2.micro"
}
