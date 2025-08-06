# outputs.tf - Root module outputs

output "autoscaling_groups" {
  description = "Auto Scaling Group details"
  value       = module.multi_tier_asg.autoscaling_groups
}

output "launch_templates" {
  description = "Launch Template details"
  value       = module.multi_tier_asg.launch_templates
}

output "scaling_policies" {
  description = "Scaling Policy details"
  value       = module.multi_tier_asg.scaling_policies
}

output "security_groups" {
  description = "Security Group details"
  value = {
    web_tier    = aws_security_group.web_tier
    app_tier    = aws_security_group.app_tier
    custom_tier = aws_security_group.custom_tier
  }
}

output "iam_instance_profiles" {
  description = "IAM Instance Profile details"
  value = {
    web_tier    = aws_iam_instance_profile.web_tier_profile
    app_tier    = aws_iam_instance_profile.app_tier_profile
    custom_tier = aws_iam_instance_profile.custom_tier_profile
  }
}

output "asg_summary" {
  description = "Summary of ASG configurations"
  value = {
    web_tier = {
      name             = module.multi_tier_asg.autoscaling_groups.web.name
      min_size         = module.multi_tier_asg.autoscaling_groups.web.min_size
      max_size         = module.multi_tier_asg.autoscaling_groups.web.max_size
      desired_capacity = module.multi_tier_asg.autoscaling_groups.web.desired_capacity
      instance_type    = "t3.medium"
      subnets         = "public"
    }
    app_tier = {
      name             = module.multi_tier_asg.autoscaling_groups.app.name
      min_size         = module.multi_tier_asg.autoscaling_groups.app.min_size
      max_size         = module.multi_tier_asg.autoscaling_groups.app.max_size
      desired_capacity = module.multi_tier_asg.autoscaling_groups.app.desired_capacity
      instance_type    = "c5.large"
      subnets         = "private"
    }
    custom_tier = {
      name             = module.multi_tier_asg.autoscaling_groups.custom.name
      min_size         = module.multi_tier_asg.autoscaling_groups.custom.min_size
      max_size         = module.multi_tier_asg.autoscaling_groups.custom.max_size
      desired_capacity = module.multi_tier_asg.autoscaling_groups.custom.desired_capacity
      instance_type    = "m5.xlarge"
      subnets         = "private"
    }
  }
}

output "deployment_summary" {
  description = "High-level deployment summary"
  value = {
    application_name = var.application_name
    environment     = var.environment
    region          = var.aws_region
    total_asgs      = length(module.multi_tier_asg.asg_names)
    asg_names       = module.multi_tier_asg.asg_names
    vpc_name        = var.vpc_name
  }
}