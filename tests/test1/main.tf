terraform {
  required_version = ">= 0.12"
}

provider "aws" {
  version = "~> 3.0"
  region  = "us-east-1"
}

provider "random" {
  version = "~> 2.1"
}

resource "random_string" "rstring" {
  length      = 8
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

  name = "${random_string.rstring.result}-VPC"
}

module "security_groups" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-security_group//?ref=master"

  environment = "Production"
  name        = "${random_string.rstring.result}-SG"
  vpc_id      = module.vpc.vpc_id
}

module "alb" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-alb//?ref=master"

  create_logging_bucket = false
  http_listeners_count  = 1
  name                  = "${random_string.rstring.result}-ALB"
  security_groups       = [module.security_groups.public_web_security_group_id]
  subnets               = module.vpc.public_subnets
  target_groups_count   = 1
  vpc_id                = module.vpc.vpc_id

  http_listeners = [
    {
      port     = 80
      protocol = "HTTP"
    },
  ]

  target_groups = [
    {
      "backend_port"     = 80
      "backend_protocol" = "HTTP"
      "name"             = "${random_string.rstring.result}-TG"
    },
  ]
}

module "clb" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-clb//?ref=master"

  connection_draining_timeout = 300
  instances                   = []
  instances_count             = 0
  name                        = "${random_string.rstring.result}-CLB"
  security_groups             = [module.security_groups.public_web_security_group_id]
  subnets                     = module.vpc.public_subnets

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

  application_name  = "${random_string.rstring.result}-TESTAPP"
  environment       = "dev"
  target_group_name = element(module.alb.target_group_names, 0)
}


module "codedeploy_tg" {
  source = "../../module"

  application_name      = module.codedeploy.application_name
  create_application    = false
  deployment_group_name = "${random_string.rstring.result}-Test-TG"
  target_group_name     = element(module.alb.target_group_names, 0)
}

module "codedeploy_clb" {
  source = "../../module"

  application_name      = module.codedeploy.application_name
  clb_name              = module.clb.name
  create_application    = false
  deployment_group_name = "${random_string.rstring.result}-Test-CLB"
}


