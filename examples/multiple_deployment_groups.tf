terraform {
  required_version = ">= 0.12"
}

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
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-vpc_basenetwork//?ref=v0.12.0"

  name = "Test1VPC"
}

module "security_groups" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-security_group//?ref=v0.12.0"

  environment = "Production"
  name        = "Test-SG"
  vpc_id      = module.vpc.vpc_id
}

module "asg_prod" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_asg//?ref=v0.12.0"

  ec2_os                   = "amazon"
  image_id                 = data.aws_ami.amz_linux_2.image_id
  install_codedeploy_agent = true
  instance_type            = "t2.micro"
  name                     = "CodeDeployExampleProd"
  security_groups          = [module.security_groups.private_web_security_group_id]
  scaling_max              = 2
  scaling_min              = 1
  subnets                  = [element(module.vpc.public_subnets, 0), element(module.vpc.public_subnets, 1)]
}

module "asg_test" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-ec2_asg//?ref=v0.12.0"

  ec2_os                   = "amazon"
  image_id                 = data.aws_ami.amz_linux_2.image_id
  install_codedeploy_agent = true
  instance_type            = "t2.micro"
  name                     = "CodeDeployExampleTest"
  security_groups          = [module.security_groups.private_web_security_group_id]
  scaling_max              = 2
  scaling_min              = 1
  subnets                  = [element(module.vpc.public_subnets, 0), element(module.vpc.public_subnets, 1)]
}

module "codedeploy_prod" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-codedeploy//?ref=v0.12.0"

  application_name   = "MyCodeDeployApp"
  autoscaling_groups = [module.asg_prod.asg_name_list]
  environment        = "Prod"
}

module "codedeploy_test" {
  source = "git@github.com:rackspace-infrastructure-automation/aws-terraform-codedeploy//?ref=v0.12.0"

  application_name       = module.codedeploy_prod.application_name
  autoscaling_groups     = [module.asg_test.asg_name_list]
  create_application     = false
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  environment            = "Test"
}

