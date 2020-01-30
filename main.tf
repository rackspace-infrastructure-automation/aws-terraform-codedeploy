/**
 * # aws-terraform-codedeploy
 *
 *This module creates a CodeDeploy deployment group and optionally a CodeDeploy application.
 *
 *## Basic Usage
 *
 *```
 *module "codedeploy_prod" {
   *source = "../codedeploy"
 *
 *  application_name   = "MyCodeDeployApp"
 *  autoscaling_groups = ["${module.asg_prod.asg_name_list}"]
 *  environment        = "Prod"
 *}
 *```
 *
 * Full working references are available at [examples](examples)
 * ## Limitations
 *
 * AWS APIs do not properly clear out the load_balancer_info field of a deployment group after removing the CLB\Target group reference.  This results in the Deployment Group trying to apply the change on every update.  We hope this behavior to be resolved after adapting Terraform v0.12.  In the meantime, a new Deployment Group should be created if the load balancer information must be removed.  This issue does not occur when replacing the referenced CLB or Target Group, or when switching between CLB and Target Groups, only when thereferences are completely removed.
 */

locals {
  application_name              = "${element(concat(aws_codedeploy_app.application.*.name, list(var.application_name)), 0)}"
  default_deployment_group_name = "${var.application_name}-${var.environment}"
  deployment_group_name         = "${var.deployment_group_name == "" ? local.default_deployment_group_name : var.deployment_group_name}"

  ec2_tag_filters = {
    enabled = [{
      key   = "${var.ec2_tag_key}"
      type  = "KEY_AND_VALUE"
      value = "${var.ec2_tag_value}"
    }]

    disabled = "${list()}"
  }

  elb_info = {
    enabled = [{
      elb_info = [{
        name = "${var.clb_name}"
      }]
    }]

    disabled = "${list()}"
  }

  enable_trafic_control = "${var.clb_name != "" || var.target_group_name != ""}"

  target_group_info = {
    enabled = [{
      target_group_info = [{
        name = "${var.target_group_name}"
      }]
    }]

    disabled = "${list()}"
  }

  set_elb_info          = "${var.clb_name == "" ? "disabled" : "enabled"}"
  set_tag_filters       = "${var.ec2_tag_key == "" ? "disabled" : "enabled"}"
  set_target_group_info = "${var.target_group_name == "" ? "disabled" : "enabled"}"
}

resource "aws_codedeploy_app" "application" {
  count = "${var.create_application ? 1 : 0}"

  name = "${var.application_name}"
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
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = "${aws_iam_role.role.name}"
}

resource "aws_codedeploy_deployment_group" "deployment_group" {
  app_name               = "${local.application_name}"
  autoscaling_groups     = ["${var.autoscaling_groups}"]
  deployment_config_name = "${var.deployment_config_name}"
  deployment_group_name  = "${local.deployment_group_name}"
  ec2_tag_filter         = "${local.ec2_tag_filters[local.set_tag_filters]}"
  service_role_arn       = "${aws_iam_role.role.arn}"

  deployment_style {
    deployment_option = "${local.enable_trafic_control ? "WITH_TRAFFIC_CONTROL" :"WITHOUT_TRAFFIC_CONTROL"}"
    deployment_type   = "IN_PLACE"
  }

  load_balancer_info = ["${concat(
    local.elb_info[local.set_elb_info],
    local.target_group_info[local.set_target_group_info],
  )}"]
}
