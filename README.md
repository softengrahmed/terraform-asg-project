# Multi-Tier Auto Scaling Group Module

A comprehensive Terraform module for deploying AWS Auto Scaling Groups across different application tiers with modern Terraform 1.12+ features.

## 🏗️ Architecture Overview

This module provides three distinct ASG configurations optimized for different workload types:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Tier      │    │   App Tier      │    │  Custom Tier    │
│                 │    │                 │    │                 │
│ • t3.medium     │    │ • c5.large      │    │ • m5.xlarge     │
│ • 2-10 instances│    │ • 2-8 instances │    │ • 1-20 instances│
│ • Public subnet │    │ • Private subnet│    │ • Private subnet│
│ • ELB health    │    │ • EC2 health    │    │ • EC2 health    │
│ • CPU scaling   │    │ • CPU + Memory  │    │ • Step + Custom │
│ • Nginx + LB    │    │ • Java + Docker │    │ • Python + K8s  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Features

### Modern Terraform Features
- **Object Types with Optional Attributes**: Complex type definitions using `optional()`
- **Advanced Validation**: Multi-condition validation with custom error messages  
- **Dynamic Resource Creation**: Using `for_each` and `dynamic` blocks
- **Complex Local Transformations**: Flattening nested structures for iteration
- **Template Functions**: Parameterized user data scripts

### AWS Best Practices
- **Security**: IMDSv2 enforcement, encrypted EBS volumes, least privilege IAM
- **Monitoring**: CloudWatch agent, custom metrics, comprehensive logging
- **Scalability**: Multiple scaling policies, target tracking, step scaling
- **High Availability**: Multi-AZ deployment, health checks, auto-recovery
- **Cost Optimization**: GP3 volumes, appropriate instance sizing per tier

## 🛠️ Quick Start

### Prerequisites
- Terraform >= 1.12.0
- AWS CLI configured
- Existing VPC with public and private subnets
- EC2 Key Pair (optional)

### Installation

1. **Clone and Setup**
```bash
git clone https://github.com/softengrahmed/terraform-asg-project.git
cd terraform-asg-project
cp terraform.tfvars.example terraform.tfvars
```

2. **Configure Variables**
```bash
vi terraform.tfvars
```

3. **Deploy Infrastructure**
```bash
terraform init
terraform plan
terraform apply
```
