# EKS Cluster
locals {
  name = format("%s-%s", var.project, var.environment)
}
# Ignoring tfsec rules for node public egress, public cluster access (needed without VPN)
# tfsec:ignore:aws-ec2-no-public-egress-sgr
# tfsec:ignore:aws-eks-no-public-cluster-access
# tfsec:ignore:aws-eks-no-public-cluster-access-to-eks-master
# tfsec:ignore:aws-eks-no-public-cluster-access-to-cidr
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20"

  cluster_name    = local.name
  cluster_version = var.cluster_version

  cluster_addons = {
    coredns    = {}
    vpc-cni    = {}
    kube-proxy = {}
  }

  # Public access should be set to false when VPN is created
  cluster_endpoint_public_access       = true
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.public_access_cidrs

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Security groups
  create_cluster_security_group = true
  create_node_security_group    = true

  enable_irsa = true

  enable_cluster_creator_admin_permissions = true

  access_entries = {
    root = {
      principal_arn = "arn:aws:iam::${var.aws_account_id}:root"

      policy_associations = {
        eks_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
        eks_cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = var.node_instance_types

    attach_cluster_primary_security_group = true

    # Needed for Karpenter
    create_iam_role = true
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }

    labels = {
      # Used to ensure Karpenter runs on nodes that it does not manage
      "karpenter.sh/controller" = "true"
    }
  }

  node_security_group_tags = merge(var.tags, {
    "karpenter.sh/discovery" = local.name
  })

  eks_managed_node_groups = var.managed_node_groups

  tags = var.tags
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20"

  cluster_name          = module.eks.cluster_name
  enable_v1_permissions = true

  enable_irsa            = true
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  # Attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = var.tags
}

provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true
  upgrade_install  = true

  name                = "karpenter"
  chart               = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  version             = var.karpenter_chart_version

  values = [
    <<-EOT
    nodeSelector:
      karpenter.sh/controller: 'true'
    dnsPolicy: Default
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    webhook:
      enabled: false
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    EOT
  ]
}
