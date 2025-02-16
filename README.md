# EKS Cluster with Karpenter and Multi-Architecture Support

This repository contains a Terraform-based setup for deploying an EKS cluster on AWS with Karpenter for efficient auto-scaling and support for both x86_64 and ARM64 architectures. It also includes:
	•	S3 + DynamoDB bootstrap (for Terraform remote state)
	•	Multiple environments (env/) with dedicated .tfvars
	•	Pre-commit configuration for Terraform linting, validation, and security scanning

[![AWS EKS](https://img.shields.io/badge/AWS-EKS-orange)]()
[![Terraform](https://img.shields.io/badge/Terraform-1.10+-blue)]()
[![Karpenter](https://img.shields.io/badge/Karpenter-Latest-green)]()


## Prerequisites

1. **Required Tools**
   - AWS CLI configured with appropriate credentials
   - Terraform (version 1.10+)
   - kubectl
   - helm
   - pre-commit (for development)

2. **Pre-commit Setup**
   ```bash
   # Install pre-commit
   pip install pre-commit

   # Install pre-commit hooks
   pre-commit install
   ```

## **Repository Structure**
```
.
├── bootstrap/
│   ├── main.tf                # Sets up remote state resources (S3 bucket, DynamoDB)
│   └── variables.tf           # Variables for bootstrap (bucket name, region, etc.)
├── env/
│   ├── dev.tfvars             # TF vars specific to 'dev' environment
│   ├── staging.tfvars         # TF vars for 'staging'
│   └── prod.tfvars            # TF vars for 'prod'
├── terraform/
│   ├── eks.tf                 # EKS cluster config (using terraform-aws-modules/eks)
│   ├── karpenter.tf           # Karpenter config (submodule + helm release)
│   ├── outputs.tf             # Outputs for cluster, Karpenter, etc.
│   ├── providers.tf           # AWS, Kubernetes providers
│   ├── shared.auto.tfvars     # Shared TF variables
│   ├── variables.tf           # Variable definitions
│   ├── karpenter/
│   │   ├── ec2nodeclass-arm64.yaml  # ARM64 EC2NodeClass
│   │   ├── ec2nodeclass-x86.yaml    # x86 EC2NodeClass
│   │   ├── nodepool-arm64.yaml      # ARM64 NodePool
│   │   └── nodepool-x86.yaml        # x86 NodePool
│   ├── examples/
│   │   ├── deployment-amd64.yaml    # Sample workload on x86
│   │   └── deployment-arm64.yaml    # Sample workload on ARM64
│   └── .terraform.lock.hcl          # Terraform provider lock file
├── .pre-commit-config.yaml          # Pre-commit hooks for Terraform checks
├── .gitignore
└── README.md                        # This file
```

### High-Level Flow
1.	bootstrap/: Creates an S3 bucket and DynamoDB table for remote Terraform state locking.
2.	env/: Each .tfvars file includes environment-specific inputs (VPC IDs, subnets, region, cluster name, etc.).
3.	terraform/: The main Terraform code for:

    •	EKS cluster creation (eks.tf)

    •	Karpenter config (node pools, node classes) (karpenter.tf + karpenter/ folder)

    •	Example workloads in examples/.

## Quick Start
### Bootstrapping Remote State

1. Initialize and apply inside the bootstrap/ directory to create the S3 bucket and DynamoDB table:
    ```bash
    cd bootstrap
    terraform init
    terraform apply
    ```
2.	Update your Terraform backend configuration in the main terraform/ folder to point to the newly created S3 bucket and DynamoDB lock table. For example:
    ```
    terraform {
      backend "s3" {
        bucket         = "my-remote-state-bucket"
        key            = "terraform/eks-k8s.tfstate"
        region         = "us-east-1"
        dynamodb_table = "my-tf-lock-table"
      }
    }
    ```

### Multiple Environments using Terraform Workspace
   ```bash
   cd terraform
   terraform init

   # Create and select workspace for your environment (e.g., dev)
   terraform workspace new dev
   terraform workspace select dev
   ```

### Deploying the EKS Cluster + Karpenter
1.	Configure your environment variables or .tfvars files (e.g., env/dev.tfvars) to specify:

    •	VPC ID, subnet IDs

    •	Desired cluster name/version

    •	Any custom tagging or IAM roles/policies

2.	In the terraform/ directory:

   ```bash
   terraform init
   terraform plan -var-file="env/dev.tfvars"
   terraform apply -var-file="env/dev.tfvars"
   ```

3. **Configure kubectl**
   ```bash
   aws eks update-kubeconfig --name <cluster-name> --region <region>
   ```

## Example Deployments

Example deployments for both x86_64 and ARM64 architectures are available in the `terraform/examples/` directory:
- [AMD64 Deployment Example](terraform/examples/deployment-amd64.yaml)
- [ARM64 Deployment Example](terraform/examples/deployment-arm64.yaml)

You can deploy these examples using:
```bash
kubectl apply -f terraform/examples/deployment-amd64.yaml
# or
kubectl apply -f terraform/examples/deployment-arm64.yaml
```

## Architecture and Cost Optimization Features

### Multi-Architecture Support
- The cluster supports both x86_64 (AMD64) and ARM64 (Graviton) instances
- Karpenter automatically provisions the most cost-effective instance type based on your workload requirements
- Use node selectors (`dedicated: x86-workloads` or `dedicated: arm64-workloads`) to target specific architectures

### Cost Optimization
- Spot instances are enabled by default for better cost savings
- For workloads requiring stable capacity, specify On-Demand instances using node affinity:

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: karpenter.sh/capacity-type
            operator: In
            values:
            - on-demand
```

## Monitoring and Troubleshooting

### Monitor Karpenter Decisions
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f
```

### Check Node Architecture
```bash
kubectl get nodes -L kubernetes.io/arch
```
