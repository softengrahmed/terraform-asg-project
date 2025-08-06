# main.tf - Root module demonstrating ASG module usage

terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.common_tags
  }
}

# Data sources for networking
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["Private"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["Public"]
  }
}

# Security Groups
resource "aws_security_group" "web_tier" {
  name        = "${var.application_name}-web-tier-sg"
  description = "Security group for web tier instances"
  vpc_id      = data.aws_vpc.main.id
  
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.application_name}-web-tier-sg"
    Tier = "web"
  }
}

resource "aws_security_group" "app_tier" {
  name        = "${var.application_name}-app-tier-sg"
  description = "Security group for application tier instances"
  vpc_id      = data.aws_vpc.main.id
  
  ingress {
    description     = "Application Port"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_tier.id]
  }
  
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }
  
  ingress {
    description = "Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.application_name}-app-tier-sg"
    Tier = "app"
  }
}

resource "aws_security_group" "custom_tier" {
  name        = "${var.application_name}-custom-tier-sg"
  description = "Security group for custom tier instances"
  vpc_id      = data.aws_vpc.main.id
  
  ingress {
    description = "Custom Application Ports"
    from_port   = 8000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }
  
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }
  
  ingress {
    description = "Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "${var.application_name}-custom-tier-sg"
    Tier = "custom"
  }
}

# IAM Instance Profiles
resource "aws_iam_role" "web_tier_role" {
  name = "${var.application_name}-web-tier-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name = "${var.application_name}-web-tier-role"
    Tier = "web"
  }
}

resource "aws_iam_role_policy_attachment" "web_tier_ssm" {
  role       = aws_iam_role.web_tier_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "web_tier_cloudwatch" {
  role       = aws_iam_role.web_tier_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "web_tier_profile" {
  name = "${var.application_name}-web-tier-profile"
  role = aws_iam_role.web_tier_role.name
  
  tags = {
    Name = "${var.application_name}-web-tier-profile"
    Tier = "web"
  }
}

resource "aws_iam_role" "app_tier_role" {
  name = "${var.application_name}-app-tier-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name = "${var.application_name}-app-tier-role"
    Tier = "app"
  }
}

resource "aws_iam_role_policy_attachment" "app_tier_ssm" {
  role       = aws_iam_role.app_tier_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "app_tier_cloudwatch" {
  role       = aws_iam_role.app_tier_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "app_tier_custom" {
  name = "${var.application_name}-app-tier-custom-policy"
  role = aws_iam_role.app_tier_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.application_name}-app-data/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.application_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "app_tier_profile" {
  name = "${var.application_name}-app-tier-profile"
  role = aws_iam_role.app_tier_role.name
  
  tags = {
    Name = "${var.application_name}-app-tier-profile"
    Tier = "app"
  }
}

resource "aws_iam_role" "custom_tier_role" {
  name = "${var.application_name}-custom-tier-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name = "${var.application_name}-custom-tier-role"
    Tier = "custom"
  }
}

resource "aws_iam_role_policy_attachment" "custom_tier_ssm" {
  role       = aws_iam_role.custom_tier_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "custom_tier_cloudwatch" {
  role       = aws_iam_role.custom_tier_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "custom_tier_policy" {
  name = "${var.application_name}-custom-tier-policy"
  role = aws_iam_role.custom_tier_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:CreateTags",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "arn:aws:s3:::${var.application_name}-custom-data",
          "arn:aws:s3:::${var.application_name}-custom-data/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "custom_tier_profile" {
  name = "${var.application_name}-custom-tier-profile"
  role = aws_iam_role.custom_tier_role.name
  
  tags = {
    Name = "${var.application_name}-custom-tier-profile"
    Tier = "custom"
  }
}

# Call the ASG module with different configurations
module "multi_tier_asg" {
  source = "./modules/asg"
  
  application_name = var.application_name
  environment     = var.environment
  common_tags     = var.common_tags
  
  asg_configurations = {
    # Web Tier ASG Configuration
    web = {
      name_prefix          = "${var.application_name}-web"
      min_size            = 2
      max_size            = 10
      desired_capacity    = 3
      vpc_zone_identifier = data.aws_subnets.public.ids
      
      instance_type = "t3.medium"
      key_name     = var.key_pair_name
      
      health_check_type         = "ELB"
      health_check_grace_period = 300
      default_cooldown         = 300
      
      launch_template = {
        security_group_ids   = [aws_security_group.web_tier.id]
        iam_instance_profile = aws_iam_instance_profile.web_tier_profile.name
        user_data_base64    = base64encode(templatefile("modules/asg/user_data/web_tier_user_data.sh", {
          environment = var.environment
          app_name   = var.application_name
        }))
        ebs_optimized      = true
        monitoring_enabled = true
        
        block_device_mappings = [
          {
            device_name = "/dev/xvda"
            ebs = {
              volume_size = 20
              volume_type = "gp3"
              delete_on_termination = true
              encrypted = true
            }
          }
        ]
      }
      
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
      
      tags = {
        Tier        = "web"
        Application = var.application_name
        Backup      = "daily"
      }
    }
    
    # Application Tier ASG Configuration
    app = {
      name_prefix          = "${var.application_name}-app"
      min_size            = 2
      max_size            = 8
      desired_capacity    = 2
      vpc_zone_identifier = data.aws_subnets.private.ids
      
      instance_type = "c5.large"
      key_name     = var.key_pair_name
      
      health_check_type         = "EC2"
      health_check_grace_period = 600
      default_cooldown         = 300
      
      launch_template = {
        security_group_ids   = [aws_security_group.app_tier.id]
        iam_instance_profile = aws_iam_instance_profile.app_tier_profile.name
        user_data_base64    = base64encode(templatefile("modules/asg/user_data/app_tier_user_data.sh", {
          environment = var.environment
          app_name   = var.application_name
        }))
        ebs_optimized      = true
        monitoring_enabled = true
        
        block_device_mappings = [
          {
            device_name = "/dev/xvda"
            ebs = {
              volume_size = 50
              volume_type = "gp3"
              delete_on_termination = true
              encrypted = true
            }
          }
        ]
      }
      
      scaling_policies = {
        cpu_scaling = {
          policy_type = "TargetTrackingScaling"
          target_tracking_configuration = {
            target_value = 60.0
            predefined_metric_specification = {
              predefined_metric_type = "ASGAverageCPUUtilization"
            }
          }
        }
        memory_scaling = {
          policy_type = "TargetTrackingScaling"
          target_tracking_configuration = {
            target_value = 80.0
            customized_metric_specification = {
              metric_name = "mem_used_percent"
              namespace   = "CWAgent"
              statistic   = "Average"
              dimensions = {
                AutoScalingGroupName = "${var.application_name}-app-asg"
              }
            }
          }
        }
      }
      
      tags = {
        Tier        = "app"
        Application = var.application_name
        Backup      = "daily"
        Monitoring  = "enhanced"
      }
    }
    
    # Custom Scaling Policy ASG Configuration
    custom = {
      name_prefix          = "${var.application_name}-custom"
      min_size            = 1
      max_size            = 20
      desired_capacity    = 3
      vpc_zone_identifier = data.aws_subnets.private.ids
      
      instance_type = "m5.xlarge"
      key_name     = var.key_pair_name
      
      health_check_type         = "EC2"
      health_check_grace_period = 900
      default_cooldown         = 600
      protect_from_scale_in    = true
      
      launch_template = {
        security_group_ids   = [aws_security_group.custom_tier.id]
        iam_instance_profile = aws_iam_instance_profile.custom_tier_profile.name
        user_data_base64    = base64encode(templatefile("modules/asg/user_data/custom_user_data.sh", {
          environment = var.environment
          app_name   = var.application_name
        }))
        ebs_optimized      = true
        monitoring_enabled = true
        
        block_device_mappings = [
          {
            device_name = "/dev/xvda"
            ebs = {
              volume_size = 100
              volume_type = "gp3"
              delete_on_termination = true
              encrypted = true
            }
          }
        ]
      }
      
      scaling_policies = {
        step_scaling_up = {
          policy_type      = "StepScaling"
          adjustment_type  = "ChangeInCapacity"
          cooldown        = 300
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
        step_scaling_down = {
          policy_type      = "StepScaling"
          adjustment_type  = "ChangeInCapacity"
          cooldown        = 300
          step_adjustments = [
            {
              metric_interval_upper_bound = 0
              scaling_adjustment         = -1
            }
          ]
        }
        custom_metric_scaling = {
          policy_type = "TargetTrackingScaling"
          target_tracking_configuration = {
            target_value = 75.0
            customized_metric_specification = {
              metric_name = "DiskUsagePercent"
              namespace   = "Custom/Application"
              statistic   = "Average"
              dimensions = {
                AutoScalingGroupName = "${var.application_name}-custom-asg"
              }
            }
          }
        }
      }
      
      tags = {
        Tier         = "custom"
        Application  = var.application_name
        Backup       = "weekly"
        Monitoring   = "custom"
        CostCenter   = "engineering"
        Project      = "data-processing"
      }
    }
  }
}