# Manage EKS with Terraform

Minimal setup for creating EKS cluster

### Prerequisites

- AWS IAM User/Role with EC2 Full Access Permission
- Proper configured AWS profile (profile name: default)
- Terraform >= 1.2.0

### Setup Guide

```bash
terraform init
terraform plan # review changes
terraform apply # apply changes
```
