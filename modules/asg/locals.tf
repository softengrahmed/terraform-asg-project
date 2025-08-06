# modules/asg/locals.tf

locals {
  # Flatten scaling policies for easy iteration
  flattened_scaling_policies = merge([
    for asg_key, asg_config in var.asg_configurations : {
      for policy_key, policy_config in asg_config.scaling_policies : 
      "${asg_key}-${policy_key}" => {
        asg_key    = asg_key
        policy_key = policy_key
        config     = policy_config
      }
    }
  ]...)
  
  # Generate user data scripts for different tiers
  base_user_data = {
    web = base64encode(templatefile("${path.module}/user_data/web_tier_user_data.sh", {
      environment = var.environment
      app_name   = var.application_name
    }))
    
    app = base64encode(templatefile("${path.module}/user_data/app_tier_user_data.sh", {
      environment = var.environment
      app_name   = var.application_name
    }))
    
    custom = base64encode(templatefile("${path.module}/user_data/custom_user_data.sh", {
      environment = var.environment
      app_name   = var.application_name
    }))
  }
  
  # Common block device mappings for different tiers
  default_block_devices = {
    web = [
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
    
    app = [
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
    
    custom = [
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
}