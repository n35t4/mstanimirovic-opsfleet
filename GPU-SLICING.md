# Enabling GPU Slicing (MIG) on AWS EKS for Cost Efficiency

## Task

One of our clients has multiple GPU-intensive AI workloads that run on EKS.

Their CTO heard there is an option to cut GPU costs by enabling GPU Slicing.

We want to help them optimize their cost efficiency.

Research the topic, and describe how they can enable GPU Slicing on their EKS clusters.

Some of the EKS clusters have Karpenter Autoscaler, they’d like to leverage GPU Slicing on these clusters as well. If this is feasible, please provide instructions on how to implement it.


## Solution overview
**GPU slicing** is commonly achieved with **NVIDIA Multi-Instance GPU (MIG)**. This allows partitioning a single physical GPU into multiple smaller GPU instances (up to 7), each isolated from the others, potentially boosting overall GPU utilization and cost savings.

This document covers:

1. **What GPU Slicing (MIG) Is**
2. **Which AWS Instances Support It**
3. **Steps to Enable MIG in EKS**
4. **Enabling MIG with Karpenter** for autoscaling
5. **Resources & References**

---

## 1. What Is GPU Slicing (MIG)?

**NVIDIA Multi-Instance GPU (MIG)** is a technology that partitions a physical GPU into smaller, independent “slices.” Each slice has dedicated memory and compute resources. This setup can help you:

- **Maximize GPU utilization**: If workloads don’t need a full GPU, you can place multiple small GPU workloads on one GPU.
- **Improve cost efficiency**: You pay for the entire GPU instance, but MIG can increase usage density, lowering total GPU count needed for the same workloads.

---

## 2. Which AWS Instances Support MIG?

- **NVIDIA A100**-based instances, such as **`p4d`** or **`p4de`**.
- Some instances in the **`g5`** family with A10G GPUs also support partial MIG functionality.

Always check AWS documentation for the latest supported instance types and details on available MIG profiles.

---

## 3. Steps to Enable MIG on EKS

### A. Use or Build a MIG-Capable AMI

- Start with an **AWS Deep Learning AMI** or **EKS-optimized AMI** that includes recent NVIDIA drivers (**450.80** or higher supports MIG).
- Optionally, create a **custom AMI** if you need additional configurations (e.g., specialized drivers, frameworks).

### B. Enable MIG at Node Startup

- **MIG is disabled** by default on A100. You enable it via `nvidia-smi -mig 1`.
- In your launch template or user data, run:

  ```bash
  #!/bin/bash
  sudo nvidia-smi -mig 1
  # Optionally create specific MIG profiles (e.g., 1g.5gb, 2g.10gb)
  ```

### C. Deploy the NVIDIA MIG Device Plugin

- Install the [NVIDIA device plugin](https://github.com/NVIDIA/k8s-device-plugin) as a DaemonSet.
- Enable MIG mode, setting `MIG_STRATEGY` evironment variable - the desired strategy for exposing MIG devices on GPUs that support it:
```yaml
- name: MIG_STRATEGY
  value: "single"
```
This will advertise MIG slices (like nvidia.com/mig-1g.5gb) as separate GPU resources in Kubernetes.

### D. Request MIG Slices in Pods
- In your pod spec, request the specific MIG resource you want:
```yaml
resources:
  limits:
    nvidia.com/mig-1g.5gb: 1
```
This ensures the pod gets exactly one 1g.5gb MIG slice. The device plugin handles the scheduling logic.

---

## 4. Using MIG with Karpenter Autoscaler

Yes, you can autoscale MIG nodes with Karpenter. Key steps:

1.	Create a Launch Template (or custom AMI) that enables MIG at boot.
2.	Reference that Launch Template in your Karpenter NodePool or EC2NodeClass:

```yaml
apiVersion: aws.karpenter.sh/v1alpha1
kind: EC2NodeClass
metadata:
  name: a100-nodeclass
spec:
  launchTemplateName: "my-a100-mig-lt"
  subnetSelector:
    karpenter.sh/discovery: my-cluster
  securityGroupSelector:
    karpenter.sh/discovery: my-cluster
```
3.	Deploy the MIG-capable device plugin.
4.	Pods that request MIG resources (e.g., nvidia.com/mig-1g.5gb) will trigger Karpenter to provision or scale new MIG-enabled instances if needed.

---

## 5. Resources & References

-	[AWS Blog on GPU Partitioning](https://aws.amazon.com/blogs/containers/gpu-sharing-on-amazon-eks-with-nvidia-time-slicing-and-accelerated-ec2-instances/)
-	[NVIDIA MIG Overview](https://developer.nvidia.com/blog/improving-gpu-utilization-in-kubernetes/)
-	[NVIDIA k8s-device-plugin for MIG](https://github.com/NVIDIA/k8s-device-plugin)
-	[Karpenter EC2NodeClass Documentation](https://karpenter.sh/v0.32/concepts/nodeclasses/)
