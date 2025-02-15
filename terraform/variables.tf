# IAC Framework
variable "team" {
  description = "Client ID (team)"
  type        = string
  validation {
    condition     = length(var.team) >= 1
    error_message = "Client_is must not be empty."
  }
}

variable "project" {
  description = "Project ID"
  type        = string
  validation {
    condition     = length(var.project) >= 3 && length(var.project) <= 26
    error_message = "Project must be between 3-25 characters."
  }
}

variable "project_repo" {
  description = "Project source control repository"
  type        = string
  validation {
    condition     = length(var.project_repo) > 10
    error_message = "Project repository address must be > 10 characters."
  }
}

variable "environment" {
  description = "Environment eg dev"
  type        = string
  validation {
    condition     = contains(["dev", "prd", "stg"], var.environment)
    error_message = "Client_environment must be one of the following 'dev, prd'."
  }
}

variable "aws_account_id" {
  description = "Account ID"
  type        = string

  validation {
    condition     = length(var.aws_account_id) == 12
    error_message = "aws_account_id must be 12 characters long."
  }
}

variable "aws_region" {
  description = "Cloud Location (region)"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the cluster"
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "node_instance_types" {
  description = "List of instance types for the EKS managed node groups"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "managed_node_groups" {
  description = "Map of EKS managed node group definitions"
  type        = any
  default = {
    initial = {
      min_size     = 1
      max_size     = 5
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks which can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = []
}

variable "karpenter_chart_version" {
  type        = string
  description = "Which version of the Karpenter Helm chart to install"
  default     = "1.1.2"
}
