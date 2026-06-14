variable "aws_region" {
  description = "AWS region for the dev environment."
  type        = string
  default     = "us-east-1"
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
