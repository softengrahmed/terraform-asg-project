# modules/asg/main.tf

terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get latest Amazon Linux 2023 AMI if not specified
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Launch Templates for each ASG configuration
resource "aws_launch_template" "asg_launch_templates" {
  for_each = var.asg_configurations
  
  name_prefix   = "${var.application_name}-${each.key}-lt-"
  description   = "Launch template for ${each.key} ASG"
  image_id      = coalesce(each.value.ami_id, data.aws_ami.amazon_linux.id)
  instance_type = each.value.instance_type
  key_name      = each.value.key_name
  
  vpc_security_group_ids = each.value.launch_template.security_group_ids
  
  # IAM Instance Profile
  dynamic "iam_instance_profile" {
    for_each = each.value.launch_template.iam_instance_profile != null ? [1] : []
    content {
      name = each.value.launch_template.iam_instance_profile
    }
  }
  
  # User Data
  user_data = each.value.launch_template.user_data_base64
  
  # EBS Optimization and Monitoring
  ebs_optimized = each.value.launch_template.ebs_optimized
  
  monitoring {
    enabled = each.value.launch_template.monitoring_enabled
  }
  
  # Block Device Mappings
  dynamic "block_device_mappings" {
    for_each = each.value.launch_template.block_device_mappings
    content {
      device_name = block_device_mappings.value.device_name
      
      ebs {
        volume_size           = block_device_mappings.value.ebs.volume_size
        volume_type          = block_device_mappings.value.ebs.volume_type
        delete_on_termination = block_device_mappings.value.ebs.delete_on_termination
        encrypted            = block_device_mappings.value.ebs.encrypted
      }
    }
  }
  
  # Metadata Options (IMDSv2)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags     = "enabled"
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.common_tags,
      each.value.tags,
      {
        Name        = "${var.application_name}-${each.key}"
        Environment = var.environment
        Tier        = each.key
      }
    )
  }
  
  tag_specifications {
    resource_type = "volume"
    tags = merge(
      var.common_tags,
      each.value.tags,
      {
        Name        = "${var.application_name}-${each.key}-volume"
        Environment = var.environment
        Tier        = each.key
      }
    )
  }
  
  lifecycle {
    create_before_destroy = true
  }
  
  tags = merge(
    var.common_tags,
    each.value.tags,
    {
      Name        = "${var.application_name}-${each.key}-lt"
      Environment = var.environment
      Tier        = each.key
    }
  )
}

# Auto Scaling Groups
resource "aws_autoscaling_group" "asg" {
  for_each = var.asg_configurations
  
  name                = "${var.application_name}-${each.key}-asg"
  vpc_zone_identifier = each.value.vpc_zone_identifier
  
  # Capacity Configuration
  min_size         = each.value.min_size
  max_size         = each.value.max_size
  desired_capacity = each.value.desired_capacity
  
  # Health Check Configuration
  health_check_type         = each.value.health_check_type
  health_check_grace_period = each.value.health_check_grace_period
  
  # Scaling Configuration
  default_cooldown                = each.value.default_cooldown
  wait_for_capacity_timeout       = each.value.wait_for_capacity_timeout
  wait_for_elb_capacity          = each.value.wait_for_elb_capacity
  protect_from_scale_in          = each.value.protect_from_scale_in
  
  # Launch Template Configuration
  launch_template {
    id      = aws_launch_template.asg_launch_templates[each.key].id
    version = "$Latest"
  }
  
  # Load Balancer Configuration
  target_group_arns = each.value.target_group_arns
  load_balancers    = each.value.load_balancers
  
  # Instance Refresh Configuration
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup       = 300
    }
  }
  
  # Termination Policies
  termination_policies = ["OldestInstance"]
  
  # Tags
  dynamic "tag" {
    for_each = merge(
      var.common_tags,
      each.value.tags,
      {
        Name        = "${var.application_name}-${each.key}"
        Environment = var.environment
        Tier        = each.key
      }
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  
  lifecycle {
    create_before_destroy = true
    ignore_changes       = [desired_capacity]
  }
  
  depends_on = [aws_launch_template.asg_launch_templates]
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scaling_policies" {
  for_each = local.flattened_scaling_policies
  
  name                   = "${var.application_name}-${each.value.asg_key}-${each.value.policy_key}"
  scaling_adjustment     = each.value.config.scaling_adjustment
  adjustment_type        = each.value.config.adjustment_type
  cooldown              = each.value.config.cooldown
  autoscaling_group_name = aws_autoscaling_group.asg[each.value.asg_key].name
  policy_type           = each.value.config.policy_type
  
  # Target Tracking Configuration
  dynamic "target_tracking_configuration" {
    for_each = each.value.config.target_tracking_configuration != null ? [each.value.config.target_tracking_configuration] : []
    content {
      target_value = target_tracking_configuration.value.target_value
      
      dynamic "predefined_metric_specification" {
        for_each = target_tracking_configuration.value.predefined_metric_specification != null ? [target_tracking_configuration.value.predefined_metric_specification] : []
        content {
          predefined_metric_type = predefined_metric_specification.value.predefined_metric_type
          resource_label        = predefined_metric_specification.value.resource_label
        }
      }
      
      dynamic "customized_metric_specification" {
        for_each = target_tracking_configuration.value.customized_metric_specification != null ? [target_tracking_configuration.value.customized_metric_specification] : []
        content {
          metric_name = customized_metric_specification.value.metric_name
          namespace   = customized_metric_specification.value.namespace
          statistic   = customized_metric_specification.value.statistic
          
          dynamic "metric_dimension" {
            for_each = customized_metric_specification.value.dimensions
            content {
              name  = metric_dimension.key
              value = metric_dimension.value
            }
          }
        }
      }
    }
  }
  
  # Step Scaling Configuration
  dynamic "step_adjustment" {
    for_each = each.value.config.step_adjustments
    content {
      metric_interval_lower_bound = step_adjustment.value.metric_interval_lower_bound
      metric_interval_upper_bound = step_adjustment.value.metric_interval_upper_bound
      scaling_adjustment         = step_adjustment.value.scaling_adjustment
    }
  }
  
  depends_on = [aws_autoscaling_group.asg]
}