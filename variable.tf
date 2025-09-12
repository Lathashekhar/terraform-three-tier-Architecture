variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "environment" {
  default = "dev"
}

variable "web_instance_type" {
  default = "t3.micro"
}

variable "app_instance_type" {
  default = "t3.small"
}

variable "db_instance_class" {
  default = "db.t3.micro"
}

variable "db_username" {
  default = "Latha"
}

variable "db_password" {
  default = "securepassword123"
}

variable "min_web_instances" {
  default = 1
}

variable "max_web_instances" {
  default = 3
}

variable "min_app_instances" {
  default = 1
}

variable "max_app_instances" {
  default = 3
}
