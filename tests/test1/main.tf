provider "aws" {
  version = "~> 1.2"
  region  = "us-east-1"
}

provider "random" {
  version = "~> 1.0"
}

resource "random_string" "rstring" {
  length      = 16
  special     = false
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
}

data "aws_ami" "amz_linux_2" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

module "vpc" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork//?ref=master"

  vpc_name = "${random_string.rstring.result}-VPC"
}

module "security_groups" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-security_group//?ref=master"

  resource_name = "${random_string.rstring.result}-SG"
  vpc_id        = "${module.vpc.vpc_id}"
  environment   = "Production"
}

module "alb" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-alb//?ref=master"

  alb_name              = "${random_string.rstring.result}-ALB"
  create_logging_bucket = false
  http_listeners_count  = 1
  security_groups       = ["${module.security_groups.public_web_security_group_id}"]
  subnets               = "${module.vpc.public_subnets}"
  target_groups_count   = 1
  vpc_id                = "${module.vpc.vpc_id}"

  http_listeners = [{
    port = 80

    protocol = "HTTP"
  }]

  target_groups = [{
    "name"             = "${random_string.rstring.result}-TargetGroup"
    "backend_protocol" = "HTTP"
    "backend_port"     = 80
  }]
}

module "clb" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-clb//?ref=master"

  clb_name                    = "${random_string.rstring.result}-CLB"
  instances                   = []
  security_groups             = ["${module.security_groups.public_web_security_group_id}"]
  subnets                     = "${module.vpc.public_subnets}"
  connection_draining_timeout = 300

  listeners = [
    {
      instance_port     = 80
      instance_protocol = "HTTP"
      lb_port           = 80
      lb_protocol       = "HTTP"
    },
  ]
}

module "codedeploy" {
  source = "../../module"

  application_name  = "${random_string.rstring.result}-APP"
  target_group_name = "${element(module.alb.target_group_names, 0)}"
}

module "codedeploy_tg" {
  source = "../../module"

  application_name      = "${module.codedeploy.application_name}"
  create_application    = false
  deployment_group_name = "${random_string.rstring.result}-DeployGroup-TG"
  target_group_name     = "${element(module.alb.target_group_names, 0)}"
}

module "codedeploy_clb" {
  source = "../../module"

  application_name      = "${module.codedeploy.application_name}"
  clb_name              = "${module.clb.clb_name}"
  create_application    = false
  deployment_group_name = "${random_string.rstring.result}-DeployGroup-CLB"
}
