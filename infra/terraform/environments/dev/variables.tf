variable "aws_region" {
  description = "AWS region for the dev environment."
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
  default     = "incidentops"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "enable_gitlab_oidc" {
  description = "Create a GitLab OIDC provider and deploy role for CI/CD."
  type        = bool
  default     = false
}

variable "gitlab_url" {
  description = "GitLab instance URL used as OIDC issuer."
  type        = string
  default     = "https://gitlab.com"
}

variable "gitlab_oidc_audience" {
  description = "Audience expected in GitLab ID tokens for AWS STS."
  type        = string
  default     = "sts.amazonaws.com"
}

variable "gitlab_project_path" {
  description = "GitLab project path, for example group/subgroup/project."
  type        = string
  default     = ""
}

variable "gitlab_deploy_branch" {
  description = "Git branch allowed to assume the GitLab deploy role."
  type        = string
  default     = "main"
}

variable "log_retention_days" {
  description = "Number of days CloudWatch keeps API and Lambda logs."
  type        = number
  default     = 14
}

variable "alarm_email" {
  description = "Email address that receives CloudWatch alarm notifications. Leave empty to disable email notifications."
  type        = string
  default     = ""
}
