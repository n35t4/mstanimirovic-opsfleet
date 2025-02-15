# IAC Framework
environment    = "dev"
aws_account_id = "943325140075"

# Project variables
cluster_version    = "1.32"
vpc_id             = "vpc-3004a24a"
private_subnet_ids = ["subnet-df940283", "subnet-5afd683d", "subnet-95e373bb"]

public_access_cidrs = ["94.189.177.76/32"]

managed_node_groups = {
  initial = {
    min_size     = 1
    max_size     = 3
    desired_size = 2

    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
  }
}
node_instance_types = ["t3.medium"]
