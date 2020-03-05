# aws-terraform-codedeploy

This module creates a CodeDeploy deployment group and optionally a CodeDeploy application.

## Basic Usage

```
module "codedeploy_prod" {
  source = "../codedeploy"

  application_name   = "MyCodeDeployApp"
  autoscaling_groups = ["${module.asg_prod.asg_name_list}"]
  environment        = "Prod"
}
```

Full working references are available at [examples](examples)
## Limitations

AWS APIs do not properly clear out the load\_balancer\_info field of a deployment group after removing the CLB\Target group reference.  This results in the Deployment Group trying to apply the change on every update.  We hope this behavior to be resolved after adapting Terraform v0.12.  In the meantime, a new Deployment Group should be created if the load balancer information must be removed.  This issue does not occur when replacing the referenced CLB or Target Group, or when switching between CLB and Target Groups, only when the references are completely removed.

## Terraform 0.12 upgrade

Several changes were required while adding terraform 0.12 compatibility.  The following changes should be

## Providers

| Name | Version |
|------|---------|
| aws | ~> 2.7 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:-----:|
| application\_name | CodeDeploy Application Name.  If an existing Application is being associated, 'create\_application' should be set to false | `string` | n/a | yes |
| autoscaling\_groups | A List of Autoscaling Group names to associate with the Deployment Group | `list(string)` | `[]` | no |
| clb\_name | The name of the CLB to associate with this Deployment Group.  If associated, the instances will be taken out of service while the application is deployed.   This variable cannot be used in conjunction with target\_group\_name. | `string` | `""` | no |
| create\_application | Boolean variable controlling if a new CodeDeploy application should be created. | `bool` | `true` | no |
| deployment\_config\_name | CodeDeploy Deployment Config Name to use as the default for this Deployment Group.  Valid values include 'CodeDeployDefault.OneAtATime', 'CodeDeployDefault.HalfAtATime', and 'CodeDeployDefault.AllAtOnce' | `string` | `"CodeDeployDefault.OneAtATime"` | no |
| deployment\_group\_name | CodeDeploy Deployment Group Name.  If omitted, name will be based on Application Group and Environment | `string` | `""` | no |
| ec2\_tag\_key | Tag key for the Deployment Groups EC2 Tag Filter.  If omitted, no EC2 Tag Filter will be applied. | `string` | `""` | no |
| ec2\_tag\_value | Tag value for the Deployment Groups EC2 Tag Filter. | `string` | `""` | no |
| environment | Application environment for which this infrastructure is being created. e.g. Development/Production. | `string` | `"Production"` | no |
| target\_group\_name | The name of the Target Group to associate with this Deployment Group.  If associated, the instances will be taken out of service while the application is deployed.  This variable cannot be used in conjunction with clb\_name. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| application\_name | CodeDeploy Application Name |
| deployment\_group\_iam\_role | IAM Role associated to the CodeDeploy Deployment Group |
| deployment\_group\_iam\_role\_arn | IAM Role associated to the CodeDeploy Deployment Group |
| deployment\_group\_name | CodeDeploy Application Name |

