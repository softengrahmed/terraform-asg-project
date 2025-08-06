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

## 📁 Project Structure

```
terraform-asg-project/
├── main.tf                              # Root module calling code
├── variables.tf                         # Root module variables  
├── outputs.tf                           # Root module outputs
├── terraform.tfvars.example             # Example configuration
├── README.md                            # This file
├── .gitignore                           # Git ignore rules
└── modules/
    └── asg/
        ├── variables.tf                 # Complex object type definitions
        ├── main.tf                      # ASG resources with modern features
        ├── locals.tf                    # Local transformations
        ├── outputs.tf                   # Module outputs
        └── user_data/
            ├── web_tier_user_data.sh    # Web server bootstrap
            ├── app_tier_user_data.sh    # Application bootstrap  
            └── custom_user_data.sh      # Custom workload bootstrap
```

## 🎯 Use Cases

### 1. Web Tier ASG
**Purpose**: Frontend web servers with load balancer integration

- **Instance Type**: `t3.medium` (burstable performance)
- **Placement**: Public subnets for ALB access
- **Scaling**: CPU target tracking at 70%
- **Health Check**: ELB-based health checks
- **Software Stack**: Nginx, CloudWatch agent, log rotation
- **Security**: HTTP/HTTPS from internet, SSH from VPC

### 2. Application Tier ASG  
**Purpose**: Backend application servers for business logic

- **Instance Type**: `c5.large` (compute optimized)
- **Placement**: Private subnets for security
- **Scaling**: CPU (60%) + Memory (80%) target tracking
- **Health Check**: EC2-based with longer grace period
- **Software Stack**: Java 17, Docker, Node Exporter
- **Security**: App port access from web tier only

### 3. Custom Scaling Policy ASG
**Purpose**: Specialized workloads with advanced scaling requirements

- **Instance Type**: `m5.xlarge` (balanced compute/memory)
- **Placement**: Private subnets with enhanced monitoring
- **Scaling**: Step scaling + custom disk usage metrics  
- **Health Check**: Custom health scripts
- **Software Stack**: Python, Docker, Kubernetes tools, Terraform
- **Security**: Custom port ranges, administrative access

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

### Example Configuration

```hcl
# terraform.tfvars
aws_region       = "us-west-2"
application_name = "myapp"
environment      = "prod"
vpc_name         = "main-vpc"
key_pair_name    = "my-key-pair"

common_tags = {
  Project     = "WebApplication"
  Environment = "Production"
  ManagedBy   = "Terraform"
  Owner       = "DevOps Team"
}
```

## ⚙️ Configuration Details

### Object Type Structure

The module uses complex object types with validation:

```hcl
variable "asg_configurations" {
  type = map(object({
    # Basic Configuration
    name_prefix     = string
    min_size       = number
    max_size       = number
    desired_capacity = number
    instance_type   = string
    
    # Optional with Defaults
    health_check_type = optional(string, "EC2")
    default_cooldown  = optional(number, 300)
    
    # Nested Objects
    launch_template = object({
      security_group_ids = list(string)
      iam_instance_profile = optional(string)
      user_data_base64   = optional(string)
      # ... more attributes
    })
    
    # Complex Nested Scaling Policies
    scaling_policies = optional(map(object({
      policy_type = optional(string, "TargetTrackingScaling")
      target_tracking_configuration = optional(object({
        target_value = number
        predefined_metric_specification = optional(object({
          predefined_metric_type = string
        }))
      }))
    })), {})
  }))
}
```

### Scaling Policy Examples

**Target Tracking (CPU)**
```hcl
scaling_policies = {
  cpu_scaling = {
    policy_type = "TargetTrackingScaling"
    target_tracking_configuration = {
      target_value = 70.0
      predefined_metric_specification = {
        predefined_metric_type = "ASGAverageCPUUtilization"
      }
    }
  }
}
```

**Custom Metrics (Memory)**
```hcl
scaling_policies = {
  memory_scaling = {
    policy_type = "TargetTrackingScaling"
    target_tracking_configuration = {
      target_value = 80.0
      customized_metric_specification = {
        metric_name = "mem_used_percent"
        namespace   = "CWAgent"
        statistic   = "Average"
      }
    }
  }
}
```

**Step Scaling**
```hcl
scaling_policies = {
  step_scaling_up = {
    policy_type     = "StepScaling"
    adjustment_type = "ChangeInCapacity"
    step_adjustments = [
      {
        metric_interval_lower_bound = 0
        metric_interval_upper_bound = 50
        scaling_adjustment         = 1
      },
      {
        metric_interval_lower_bound = 50
        scaling_adjustment         = 2
      }
    ]
  }
}
```

## 📊 Monitoring & Observability

### CloudWatch Integration
- **Metrics**: CPU, Memory, Disk, Network, Custom application metrics
- **Logs**: Application logs, system logs, audit logs
- **Dashboards**: Automated dashboard creation for each tier
- **Alarms**: Configurable thresholds for scaling and alerting

### Log Aggregation
- **Web Tier**: Nginx access/error logs, system logs
- **App Tier**: Application logs, container logs, JVM metrics  
- **Custom Tier**: Custom application logs, Docker logs, cron logs

### Health Monitoring
- **Load Balancer Health Checks**: HTTP-based health endpoints
- **Custom Health Scripts**: Comprehensive instance health validation
- **Auto Recovery**: Automatic instance replacement on health check failures

## 🔒 Security Features

### Network Security
- **Security Groups**: Tier-specific ingress/egress rules
- **Subnet Isolation**: Public/private subnet separation
- **VPC Integration**: Full VPC compliance with proper routing

### Instance Security  
- **IMDSv2**: Instance Metadata Service v2 enforcement
- **EBS Encryption**: All volumes encrypted at rest
- **IAM Roles**: Least privilege access per tier
- **Key Management**: Optional SSH key configuration

### Monitoring Security
- **CloudWatch Logs**: Centralized, encrypted log storage
- **Access Logging**: Comprehensive audit trails
- **Security Groups**: Restrictive network policies

## 💰 Cost Optimization

### Instance Optimization
- **Right-sized Instances**: Appropriate instance types per workload
- **GP3 Volumes**: Cost-effective storage with better performance
- **Spot Integration**: Ready for spot instance integration

### Scaling Efficiency
- **Target Tracking**: Efficient scaling based on actual utilization
- **Cool-down Periods**: Prevent rapid scaling oscillations
- **Instance Protection**: Protect critical instances from scale-in

## 🧪 Testing

### Validation
```bash
# Validate syntax and configuration
terraform validate

# Check formatting
terraform fmt -check

# Security scanning
tfsec .

# Cost estimation
terraform plan -out=tfplan
terraform show -json tfplan | infracost breakdown --path=-
```

### Deployment Testing
```bash
# Plan deployment
terraform plan -var-file="terraform.tfvars"

# Apply with approval
terraform apply -var-file="terraform.tfvars"

# Verify resources
aws autoscaling describe-auto-scaling-groups
aws ec2 describe-launch-templates
```

## 📈 Scaling

### Horizontal Scaling
- **Web Tier**: 2-10 instances based on traffic
- **App Tier**: 2-8 instances based on CPU/memory
- **Custom Tier**: 1-20 instances with advanced policies

### Vertical Scaling
- Instance types can be modified in the configuration
- Launch template updates trigger rolling deployments
- Zero-downtime scaling with instance refresh

## 🔄 CI/CD Integration

### Pipeline Integration
```yaml
# Example GitHub Actions
- name: Terraform Plan
  run: terraform plan -var-file="terraform.tfvars"
  
- name: Terraform Apply
  run: terraform apply -auto-approve -var-file="terraform.tfvars"
  if: github.ref == 'refs/heads/main'
```

### Environment Promotion
- **Development**: Smaller instances, relaxed policies
- **Staging**: Production-like with limited capacity  
- **Production**: Full capacity with strict policies

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For questions and support:
- Create an issue in the repository
- Contact the DevOps team
- Check the troubleshooting section below

## 🐛 Troubleshooting

### Common Issues

**Issue**: Launch template update fails
```bash
# Solution: Update ASG to use new launch template version
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name <asg-name> \
  --launch-template LaunchTemplateId=<template-id>,Version='$Latest'
```

**Issue**: Scaling policies not triggering
```bash
# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=AutoScalingGroupName,Value=<asg-name>
```

**Issue**: Health checks failing
```bash
# Check instance logs
aws logs get-log-events \
  --log-group-name /aws/ec2/<app-name>/<env>/application \
  --log-stream-name <instance-id>
```

## 📚 Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Auto Scaling User Guide](https://docs.aws.amazon.com/autoscaling/ec2/userguide/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

## 🚀 Getting Started Summary

1. **Clone**: `git clone https://github.com/softengrahmed/terraform-asg-project.git`
2. **Configure**: `cp terraform.tfvars.example terraform.tfvars` and edit
3. **Deploy**: `terraform init && terraform apply`
4. **Monitor**: Check CloudWatch dashboards and ASG health
5. **Scale**: Modify configurations and apply for updates

**Key Features**: Modern Terraform 1.12+ syntax, production-ready security, comprehensive monitoring, and three distinct use cases for web, application, and custom workloads.
