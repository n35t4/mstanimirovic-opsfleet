# Karpenter
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

# provider "aws" {
#   region = "us-east-1"
#   alias  = "virginia"
# }

# data "aws_ecrpublic_authorization_token" "token" {
#   provider = aws.virginia
# }

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true
  upgrade_install  = true

  name       = "karpenter"
  chart      = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  #   repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  #   repository_password = data.aws_ecrpublic_authorization_token.token.password
  version = var.karpenter_chart_version

  values = [
    <<-EOT
    nodeSelector:
      karpenter.sh/controller: 'true'
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    EOT
  ]
}

resource "kubernetes_manifest" "ec2nodeclass_x86" {
  manifest = yamldecode(
    templatefile("${path.module}/karpenter/ec2nodeclass-x86.yaml", {
      cluster_name = module.eks.cluster_name
      node_role    = module.karpenter.node_iam_role_name
      environment  = var.environment
      owner        = var.team
      project_repo = var.project_repo
      project      = var.project
    })
  )
  depends_on = [resource.helm_release.karpenter]
}

resource "kubernetes_manifest" "nodepool_x86" {
  manifest   = yamldecode(file("${path.module}/karpenter/nodepool-x86.yaml"))
  depends_on = [resource.kubernetes_manifest.ec2nodeclass_x86]
}

resource "kubernetes_manifest" "ec2nodeclass_arm64" {
  manifest = yamldecode(
    templatefile("${path.module}/karpenter/ec2nodeclass-arm64.yaml", {
      cluster_name = module.eks.cluster_name
      node_role    = module.karpenter.node_iam_role_name
      environment  = var.environment
      owner        = var.team
      project_repo = var.project_repo
      project      = var.project
    })
  )
  depends_on = [resource.helm_release.karpenter]
}

resource "kubernetes_manifest" "nodepool_arm64" {
  manifest   = yamldecode(file("${path.module}/karpenter/nodepool-arm64.yaml"))
  depends_on = [resource.kubernetes_manifest.ec2nodeclass_arm64]
}
