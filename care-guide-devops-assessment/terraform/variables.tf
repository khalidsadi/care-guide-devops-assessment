variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ami_id" {
  type        = string
  description = "A current Amazon Linux 2023 AMI ID for your region."
}

variable "allowed_ssh_cidr" {
  type        = string
  default     = null
  description = "Optional trusted CIDR for SSH. Prefer SSM and leave null."
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "name_prefix" {
  type    = string
  default = "care-guide-devops"
}
