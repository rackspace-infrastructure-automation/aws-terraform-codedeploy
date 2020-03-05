variable "application_name" {
  description = "CodeDeploy Application Name.  If an existing Application is being associated, 'create_application' should be set to false"
  type        = string
}

variable "autoscaling_groups" {
  description = "A List of Autoscaling Group names to associate with the Deployment Group"
  default     = []
  type        = list(string)
}

variable "clb_name" {
  description = "The name of the CLB to associate with this Deployment Group.  If associated, the instances will be taken out of service while the application is deployed.   This variable cannot be used in conjunction with target_group_name."
  type        = string
  default     = ""
}

variable "create_application" {
  description = "Boolean variable controlling if a new CodeDeploy application should be created."
  default     = true
  type        = bool
}

variable "deployment_config_name" {
  description = "CodeDeploy Deployment Config Name to use as the default for this Deployment Group.  Valid values include 'CodeDeployDefault.OneAtATime', 'CodeDeployDefault.HalfAtATime', and 'CodeDeployDefault.AllAtOnce'"
  default     = "CodeDeployDefault.OneAtATime"
  type        = string
}

variable "deployment_group_name" {
  description = "CodeDeploy Deployment Group Name.  If omitted, name will be based on Application Group and Environment"
  default     = ""
  type        = string
}

variable "ec2_tag_key" {
  description = "Tag key for the Deployment Groups EC2 Tag Filter.  If omitted, no EC2 Tag Filter will be applied."
  default     = ""
  type        = string
}

variable "ec2_tag_value" {
  description = "Tag value for the Deployment Groups EC2 Tag Filter."
  default     = ""
  type        = string
}

variable "environment" {
  description = "Application environment for which this infrastructure is being created. e.g. Development/Production."
  default     = "Production"
  type        = string
}

variable "target_group_name" {
  description = "The name of the Target Group to associate with this Deployment Group.  If associated, the instances will be taken out of service while the application is deployed.  This variable cannot be used in conjunction with clb_name."
  default     = ""
  type        = string
}

