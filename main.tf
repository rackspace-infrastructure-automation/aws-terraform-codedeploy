/*
 * # aws-terraform-codedeploy
 *
 * This module creates a CodeDeploy deployment group and optionally a CodeDeploy application.
 *
 * ## Basic Usage
 *
 * ```
 * module "codedeploy_prod" {
 *   source = "../codedeploy"
 *
 *   application_name   = "MyCodeDeployApp"
 *   autoscaling_groups = ["${module.asg_prod.asg_name_list}"]
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
 *
 * Several changes were required while adding terraform 0.12 compatibility.  The following changes should be  
made when upgrading from a previous release to version 0.12.0 or higher.
 */

terraform {
  required_version = ">= 0.12"

  required_providers {
    aws = "~> 2.7"
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
    enabled = [
      {
        key   = var.ec2_tag_key
        type  = "KEY_AND_VALUE"
        value = var.ec2_tag_value
      },
    ]
    disabled = []
  }

  elb_info = {
    enabled = [
      {
        elb_info = [
          {
            name = var.clb_name
          },
        ]
      },
    ]
    disabled = []
  }

  enable_trafic_control = var.clb_name != "" || var.target_group_name != ""

  target_group_info = {
    enabled = [
      {
        target_group_info = [
          {
            name = var.target_group_name
          },
        ]
      },
    ]
    disabled = []
  }

  set_elb_info          = var.clb_name == "" ? "disabled" : "enabled"
  set_tag_filters       = var.ec2_tag_key == "" ? "disabled" : "enabled"
  set_target_group_info = var.target_group_name == "" ? "disabled" : "enabled"
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

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.role.name
}

resource "aws_codedeploy_deployment_group" "deployment_group" {
  app_name               = local.application_name
  autoscaling_groups     = var.autoscaling_groups
  deployment_config_name = var.deployment_config_name
  deployment_group_name  = local.deployment_group_name
  dynamic "ec2_tag_filter" {
    for_each = local.ec2_tag_filters[local.set_tag_filters]
    content {
      # TF-UPGRADE-TODO: The automatic upgrade tool can't predict
      # which keys might be set in maps assigned here, so it has
      # produced a comprehensive set here. Consider simplifying
      # this after confirming which keys can be set in practice.

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

  dynamic "load_balancer_info" {
    for_each = [concat(
      local.elb_info[local.set_elb_info],
      local.target_group_info[local.set_target_group_info],
    )]
    content {
      # TF-UPGRADE-TODO: The automatic upgrade tool can't predict
      # which keys might be set in maps assigned here, so it has
      # produced a comprehensive set here. Consider simplifying
      # this after confirming which keys can be set in practice.

      dynamic "elb_info" {
        for_each = lookup(load_balancer_info.value, "elb_info", [])
        content {
          name = lookup(elb_info.value, "name", null)
        }
      }

      dynamic "target_group_info" {
        for_each = lookup(load_balancer_info.value, "target_group_info", [])
        content {
          name = lookup(target_group_info.value, "name", null)
        }
      }

      dynamic "target_group_pair_info" {
        for_each = lookup(load_balancer_info.value, "target_group_pair_info", [])
        content {
          dynamic "prod_traffic_route" {
            for_each = lookup(target_group_pair_info.value, "prod_traffic_route", [])
            content {
              listener_arns = prod_traffic_route.value.listener_arns
            }
          }

          dynamic "target_group" {
            for_each = lookup(target_group_pair_info.value, "target_group", [])
            content {
              name = target_group.value.name
            }
          }

          dynamic "test_traffic_route" {
            for_each = lookup(target_group_pair_info.value, "test_traffic_route", [])
            content {
              listener_arns = test_traffic_route.value.listener_arns
            }
          }
        }
      }
    }
  }
}
