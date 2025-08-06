# modules/asg/outputs.tf

output "autoscaling_groups" {
  description = "Auto Scaling Group configurations"
  value = {
    for key, asg in aws_autoscaling_group.asg : key => {
      arn                    = asg.arn
      id                     = asg.id
      name                   = asg.name
      min_size              = asg.min_size
      max_size              = asg.max_size
      desired_capacity      = asg.desired_capacity
      default_cooldown      = asg.default_cooldown
      health_check_type     = asg.health_check_type
      availability_zones    = asg.availability_zones
      vpc_zone_identifier   = asg.vpc_zone_identifier
      target_group_arns     = asg.target_group_arns
      load_balancers        = asg.load_balancers
    }
  }
}

output "launch_templates" {
  description = "Launch Template configurations"
  value = {
    for key, lt in aws_launch_template.asg_launch_templates : key => {
      arn           = lt.arn
      id            = lt.id
      name          = lt.name
      latest_version = lt.latest_version
      default_version = lt.default_version
    }
  }
}

output "scaling_policies" {
  description = "Auto Scaling Policy configurations"
  value = {
    for key, policy in aws_autoscaling_policy.scaling_policies : key => {
      arn                    = policy.arn
      name                   = policy.name
      policy_type           = policy.policy_type
      adjustment_type       = policy.adjustment_type
      scaling_adjustment    = policy.scaling_adjustment
      cooldown             = policy.cooldown
      autoscaling_group_name = policy.autoscaling_group_name
    }
  }
}

output "asg_names" {
  description = "List of Auto Scaling Group names"
  value       = [for asg in aws_autoscaling_group.asg : asg.name]
}

output "launch_template_ids" {
  description = "Map of launch template IDs by configuration key"
  value       = { for key, lt in aws_launch_template.asg_launch_templates : key => lt.id }
}

output "asg_arns" {
  description = "Map of Auto Scaling Group ARNs by configuration key"
  value       = { for key, asg in aws_autoscaling_group.asg : key => asg.arn }
}