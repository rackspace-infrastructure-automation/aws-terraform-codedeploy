provider "aws" {
  version = "~> 1.2"
  region  = "us-east-1"
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
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork//?ref=v0.0.10"

  vpc_name = "Test1VPC"
}

module "security_groups" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-security_group//?ref=v0.0.6"

  environment   = "Production"
  resource_name = "Test-SG"
  vpc_id        = "${module.vpc.vpc_id}"
}

module "alb" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-alb//?ref=v0.0.11"

  alb_name              = "CodeDeployExample-ALB"
  create_logging_bucket = false
  http_listeners_count  = 1
  security_groups       = ["${module.security_groups.public_web_security_group_id}"]
  subnets               = "${module.vpc.public_subnets}"
  target_groups_count   = 1
  vpc_id                = "${module.vpc.vpc_id}"

  http_listeners = [{
    port     = 80
    protocol = "HTTP"
  }]

  target_groups = [{
    "backend_port"     = 80
    "backend_protocol" = "HTTP"
    "name"             = "CodeDeployExample-TargetGroup"
  }]
}

module "asg" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_asg//?ref=v0.0.24"

  ec2_os                   = "amazon"
  image_id                 = "${data.aws_ami.amz_linux_2.image_id}"
  install_codedeploy_agent = "True"
  instance_type            = "t2.micro"
  resource_name            = "CodeDeployExample"
  scaling_max              = "2"
  scaling_min              = "1"
  security_group_list      = ["${module.security_groups.private_web_security_group_id}"]
  subnets                  = ["${element(module.vpc.public_subnets, 0)}", "${element(module.vpc.public_subnets, 1)}"]
  target_group_arns        = "${module.alb.target_group_arns}"
}

module "codedeploy" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-codedeploy//?ref=v0.0.3"

  application_name      = "MyCodeDeployApp"
  autoscaling_groups    = ["${module.asg.asg_name_list}"]
  deployment_group_name = "MyCodeDeployDeploymentGroup"
  target_group_name     = "${element(module.alb.target_group_names, 0)}"
}
