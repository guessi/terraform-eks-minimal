data "aws_availability_zones" "available" {}

locals {
  cluster_name    = "tf-eks-demo"
  region          = "us-east-1"
  cluster_version = "1.30"

  ami_type_AL2    = "AL2_x86_64"
  ami_type_AL2023 = "AL2023_x86_64_STANDARD"
  disk_size       = 30

  instance_type = [
    "t3a.small",
    "t3.small",
  ]

  min_size     = 2
  max_size     = 5
  desired_size = 2

  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  vpc_cidr = "10.0.0.0/16"

  cluster_ip_family         = "ipv4"
  cluster_service_ipv4_cidr = "10.100.0.0/16"

  tags = {
    Terraform = true
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.20.0"

  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    kube-proxy = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    coredns = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      most_recent       = true
      before_compute    = true
      resolve_conflicts = "OVERWRITE"
    }
    eks-pod-identity-agent = {
      most_recent       = true
      before_compute    = true
      resolve_conflicts = "OVERWRITE"
    }
  }

  node_security_group_additional_rules = {
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_ip_family         = local.cluster_ip_family
  cluster_service_ipv4_cidr = local.cluster_service_ipv4_cidr

  eks_managed_node_group_defaults = {
    disk_size      = local.disk_size
    instance_types = local.instance_type

    # We are using the IRSA created below for permissions
    # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster)
    # and then turn this off after the cluster/node group is created. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the cluster
    # See https://github.com/aws/containers-roadmap/issues/1666 for more context
    iam_role_attach_cni_policy = true
  }

  // HINT: be aware of the desired_size changes
  // - https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/faq.md#why-are-there-no-changes-when-a-node-groups-desired_size-is-modified
  // - https://github.com/bryantbiggs/eks-desired-size-hack
  eks_managed_node_groups = {
    mng1 = {
      ami_type        = local.ami_type_AL2
      use_name_prefix = false

      min_size     = local.min_size
      max_size     = local.max_size
      desired_size = local.desired_size

      capacity_type = "SPOT"
    }

    al2023_nodeadm = {
      ami_type                       = local.ami_type_AL2023
      platform                       = "al2023"
      use_latest_ami_release_version = true
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  tags = local.tags
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.12.0"

  name = local.cluster_name
  cidr = local.vpc_cidr

  azs = local.azs
  private_subnets = [
    cidrsubnet(local.vpc_cidr, 8, 10),
    cidrsubnet(local.vpc_cidr, 8, 20),
  ]
  public_subnets = [
    cidrsubnet(local.vpc_cidr, 8, 30),
    cidrsubnet(local.vpc_cidr, 8, 40),
  ]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = local.cluster_name
  }

  tags = local.tags
}
