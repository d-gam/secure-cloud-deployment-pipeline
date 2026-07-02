variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "eu-west-1" # Ireland — closest AWS region to Spain
}

variable "project_name" {
  description = "Name prefix used for tagging and naming resources"
  type        = string
  default     = "secure-cloud-pipeline"
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
  default     = "dev"
}
