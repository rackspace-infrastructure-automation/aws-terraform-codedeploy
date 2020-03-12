output "application_name" {
  description = "CodeDeploy Application Name"
  value       = local.application_name
}

output "deployment_group_iam_role" {
  description = "IAM Role associated to the CodeDeploy Deployment Group"
  value       = aws_iam_role.role.name
}

output "deployment_group_iam_role_arn" {
  description = "IAM Role associated to the CodeDeploy Deployment Group"
  value       = aws_iam_role.role.arn
}

output "deployment_group_name" {
  description = "CodeDeploy Application Name"
  value       = aws_codedeploy_deployment_group.deployment_group.deployment_group_name
}

