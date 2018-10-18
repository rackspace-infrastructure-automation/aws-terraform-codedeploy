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

AWS APIs do not properly clear out the load_balancer_info field of a deployment group after removing the CLB\Target group reference.  This results in the Deployment Group trying to apply the change on every update.  We hope this behavior to be resolved after adapting Terraform v0.12.  In the meantime, a new Deployment Group should be created if the load balancer information must be removed.  This issue does not occur when replacing the referenced CLB or Target Group, or when switching between CLB and Target Groups, only when thereferences are completely removed.


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| application_name | CodeDeploy Application Name.  If an existing Application is being associated, 'create_application' should be set to false | string | - | yes |
| autoscaling_groups | A List of Autoscaling Group names to associate with the Deployment Group | list | `<list>` | no |
| clb_name | The name of the CLB to associate with this Deployment Group.  If associated, the instances will be taken out of service while the application is deployed.   This variable cannot be used in conjunction with target_group_name. | string | `` | no |
| create_application | Boolean variable controlling if a new CodeDeploy application should be created. | string | `true` | no |
| deployment_config_name | CodeDeploy Deployment Config Name to use as the default for this Deployment Group.  Valid values include 'CodeDeployDefault.OneAtATime', 'CodeDeployDefault.HalfAtATime', and 'CodeDeployDefault.AllAtOnce' | string | `CodeDeployDefault.OneAtATime` | no |
| deployment_group_name | CodeDeploy Deployment Group Name.  If omitted, name will be based on Application Group and Environment | string | `` | no |
| ec2_tag_key | Tag key for the Deployment Groups EC2 Tag Filter.  If omitted, no EC2 Tag Filter will be applied. | string | `` | no |
| ec2_tag_value | Tag value for the Deployment Groups EC2 Tag Filter. | string | `` | no |
| environment | Application environment for which this infrastructure is being created. e.g. Development/Production. | string | `Production` | no |
| target_group_name | The name of the Target Group to associate with this Deployment Group.  If associated, the instances will be taken out of service while the application is deployed.  This variable cannot be used in conjunction with clb_name. | string | `` | no |

## Outputs

| Name | Description |
|------|-------------|
| application_name | CodeDeploy Application Name |
| deployment_group_iam_role | IAM Role associated to the CodeDeploy Deployment Group |
| deployment_group_iam_role_arn | IAM Role associated to the CodeDeploy Deployment Group |
| deployment_group_name | CodeDeploy Application Name |

