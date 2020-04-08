/*
 * # aws-terraform-codedeploy
 *
 * This module creates a CodeDeploy deployment group and optionally a CodeDeploy application.
 *
 * ## Basic Usage
 *
 * ```
 * module "codedeploy_prod" {
 *   source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-codedeploy//?ref=v0.12.0"
 *
 *   application_name   = "MyCodeDeployApp"
 *   autoscaling_groups = ["myASG"]
 *   environment        = "Prod"
 * }
 * ```
 *
 * Full working references are available at [examples](examples)
 * ## Limitations
 *
 * AWS APIs do not properly clear out the load_balancer_info field of a deployment group after removing the CLB\Target group reference.  This results in the Deployment Group trying to apply the change on every update.  We hope this behavior to be resolved after adapting Terraform v0.12.  In the meantime, a new Deployment Group should be created if the load balancer information must be removed.  This issue does not occur when replacing the referenced CLB or Target Group, or when switching between CLB and Target Groups, only when the references are completely removed.
 *
 * ## Terraform 0.12 upgrade
 *  No changes are necessary when upgrading to the 0.12 compliant version of this module.
 */

terraform {
  required_version = ">= 0.12"

  required_providers {
    aws = ">= 2.7.0"
  }
}

locals {
  application_name = element(
    concat(
      aws_codedeploy_app.application.*.name,
      [var.application_name],
    ),
    0,
  )
  default_deployment_group_name = "${var.application_name}-${var.environment}"
  deployment_group_name         = var.deployment_group_name == "" ? local.default_deployment_group_name : var.deployment_group_name

  ec2_tag_filters = {
    key   = var.ec2_tag_key
    type  = "KEY_AND_VALUE"
    value = var.ec2_tag_value

  }

  enable_trafic_control = var.clb_name != "" || var.target_group_name != ""
}

resource "aws_codedeploy_app" "application" {
  count = var.create_application ? 1 : 0

  name = var.application_name
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "role" {
  name_prefix        = "${local.deployment_group_name}-"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "code_deploy_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.role.name
}

resource "aws_codedeploy_deployment_group" "deployment_group" {
  app_name               = local.application_name
  autoscaling_groups     = var.autoscaling_groups
  deployment_config_name = var.deployment_config_name
  deployment_group_name  = local.deployment_group_name
  dynamic "ec2_tag_filter" {
    for_each = var.ec2_tag_key != "" && var.ec2_tag_value != "" ? [local.ec2_tag_filters] : []
    content {
      key   = lookup(ec2_tag_filter.value, "key", null)
      type  = lookup(ec2_tag_filter.value, "type", null)
      value = lookup(ec2_tag_filter.value, "value", null)
    }
  }
  service_role_arn = aws_iam_role.role.arn

  deployment_style {
    deployment_option = local.enable_trafic_control ? "WITH_TRAFFIC_CONTROL" : "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  load_balancer_info {
    dynamic "elb_info" {
      for_each = var.clb_name == "" ? [] : [var.clb_name]
      content {
        name = elb_info.value
      }
    }

    dynamic "target_group_info" {
      for_each = var.target_group_name == "" ? [] : [var.target_group_name]
      content {
        name = target_group_info.value
      }
    }
  }
}
