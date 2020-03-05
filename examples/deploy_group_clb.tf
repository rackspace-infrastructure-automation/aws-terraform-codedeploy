provider "aws" {
  version = "~> 2.7"
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

  name = "Test1VPC"
}

module "security_groups" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-security_group//?ref=v0.0.6"

  environment   = "Production"
  name          = "Test-SG"
  vpc_id        = "${module.vpc.vpc_id}"
}

module "clb" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-clb//?ref=v0.0.8"

  connection_draining_timeout = 300
  instances                   = []
  name                        = "CodeDeployExample-CLB"
  security_groups             = ["${module.security_groups.public_web_security_group_id}"]
  subnets                     = "${module.vpc.public_subnets}"

  listeners = [
    {
      instance_port     = 80
      instance_protocol = "HTTP"
      lb_port           = 80
      lb_protocol       = "HTTP"
    },
  ]
}

module "asg" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_asg//?ref=v0.12.0"

  ec2_os                   = "amazon"
  image_id                 = "${data.aws_ami.amz_linux_2.image_id}"
  install_codedeploy_agent = true
  instance_type            = "t2.micro"
  load_balancer_names      = ["${module.clb.clb_name}"]
  name                     = "CodeDeployExample"
  security_groups          = ["${module.security_groups.private_web_security_group_id}"]
  scaling_max              = 2
  scaling_min              = 1
  subnets                  = ["${element(module.vpc.public_subnets, 0)}", "${element(module.vpc.public_subnets, 1)}"]
}

module "codedeploy" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-codedeploy//?ref=v0.12.0"

  application_name      = "MyCodeDeployApp"
  autoscaling_groups    = ["${module.asg.asg_name_list}"]
  clb_name              = "${module.clb.clb_name}"
  deployment_group_name = "MyCodeDeployDeploymentGroup"
}
