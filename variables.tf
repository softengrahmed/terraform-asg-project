# variables.tf - Root module variables

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
  
  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in the format 'us-west-2'."
  }
}

variable "application_name" {
  description = "Name of the application"
  type        = string
  default     = "myapp"
  
  validation {
    condition = can(regex("^[a-z0-9-]+$", var.application_name))
    error_message = "Application name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "vpc_name" {
  description = "Name of the VPC to deploy resources in"
  type        = string
  default     = "main-vpc"
}

variable "key_pair_name" {
  description = "Name of the EC2 Key Pair for instance access"
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "MultiTierApp"
    ManagedBy   = "Terraform"
    Owner       = "DevOps Team"
  }
}