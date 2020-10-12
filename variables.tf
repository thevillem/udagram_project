variable aws_region {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable project {
  description = "Map of project names to configuration"
  type        = map
  default = {
    udagram = {
      public_subnet_count  = 2,
      private_subnet_count = 2,
      instances_per_subnet = 1,
      instance_type        = "t2.small",
      ami_id               = "ami-0dba2cb6798deb6d8",
      environment          = "prod"
    }
  }
}

variable vpc_cidr_block {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable public_subnet_cidr_blocks {
  description = "Available cidr blocks for public subnets"
  type        = list(string)
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}

variable private_subnet_cidr_blocks {
  description = "Available cidr blocks for private subnets"
  type        = list(string)
  default = [
    "10.0.101.0/24",
    "10.0.102.0/24"
  ]
}