# modules/asg/variables.tf
# Complex object types with validation and optional attributes

variable "asg_configurations" {
  description = "Map of ASG configurations for different tiers"
  type = map(object({
    # Basic ASG Configuration
    name_prefix          = string
    min_size            = number
    max_size            = number
    desired_capacity    = number
    vpc_zone_identifier = list(string)
    
    # Instance Configuration
    instance_type        = string
    ami_id              = optional(string)
    key_name            = optional(string)
    
    # Health Check Configuration
    health_check_type         = optional(string, "EC2")
    health_check_grace_period = optional(number, 300)
    
    # Scaling Configuration
    default_cooldown                = optional(number, 300)
    wait_for_capacity_timeout       = optional(string, "10m")
    wait_for_elb_capacity          = optional(number)
    protect_from_scale_in          = optional(bool, false)
    
    # Launch Template Configuration
    launch_template = object({
      security_group_ids = list(string)
      iam_instance_profile = optional(string)
      user_data_base64    = optional(string)
      ebs_optimized       = optional(bool, true)
      monitoring_enabled  = optional(bool, true)
      
      block_device_mappings = optional(list(object({
        device_name = string
        ebs = object({
          volume_size           = number
          volume_type          = optional(string, "gp3")
          delete_on_termination = optional(bool, true)
          encrypted            = optional(bool, true)
        })
      })), [])
    })
    
    # Load Balancer Configuration
    target_group_arns    = optional(list(string), [])
    load_balancers       = optional(list(string), [])
    
    # Scaling Policies
    scaling_policies = optional(map(object({
      policy_type               = optional(string, "TargetTrackingScaling")
      adjustment_type          = optional(string)
      scaling_adjustment       = optional(number)
      cooldown                = optional(number)
      
      # Target Tracking Configuration
      target_tracking_configuration = optional(object({
        target_value = number
        predefined_metric_specification = optional(object({
          predefined_metric_type = string
          resource_label        = optional(string)
        }))
        customized_metric_specification = optional(object({
          metric_name = string
          namespace   = string
          statistic   = string
          dimensions = optional(map(string), {})
        }))
      }))
      
      # Step Scaling Configuration
      step_adjustments = optional(list(object({
        metric_interval_lower_bound = optional(number)
        metric_interval_upper_bound = optional(number)
        scaling_adjustment         = number
      })), [])
    })), {})
    
    # Tags
    tags = optional(map(string), {})
  }))
  
  validation {
    condition = alltrue([
      for config in var.asg_configurations : 
      config.min_size <= config.desired_capacity && config.desired_capacity <= config.max_size
    ])
    error_message = "Desired capacity must be between min_size and max_size for all configurations."
  }
  
  validation {
    condition = alltrue([
      for config in var.asg_configurations :
      contains(["EC2", "ELB"], config.health_check_type)
    ])
    error_message = "Health check type must be either 'EC2' or 'ELB'."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "application_name" {
  description = "Name of the application"
  type        = string
}