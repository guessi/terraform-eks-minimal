locals {
  cluster_name    = "tf-eks-demo"
  region          = "us-east-1"
  cluster_version = "1.24"

  ami_type  = "AL2_x86_64"
  disk_size = 30

  instance_type = [
    "t3a.small",
    "t3.small",
  ]

  min_size     = 2
  max_size     = 5
  desired_size = 2

  vpc_cidr            = "10.0.0.0/16"
  vpc_private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]
  vpc_public_subnets  = ["10.0.30.0/24", "10.0.40.0/24"]

  cluster_ip_family         = "ipv4"
  cluster_service_ipv4_cidr = "10.100.0.0/16"

  tags = {
    Terraform = true
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.30"

  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_addons = {
    kube-proxy = {
      resolve_conflicts = "OVERWRITE"
    }
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_ip_family         = local.cluster_ip_family
  cluster_service_ipv4_cidr = local.cluster_service_ipv4_cidr

  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
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

  eks_managed_node_group_defaults = {
    ami_type       = local.ami_type
    disk_size      = local.disk_size
    instance_types = local.instance_type
  }

  eks_managed_node_groups = {
    mng1 = {
      use_name_prefix = false

      min_size     = local.min_size
      max_size     = local.max_size
      desired_size = local.desired_size

      capacity_type = "SPOT"

      update_config = {
        max_unavailable_percentage = 25 # or set `max_unavailable`
      }
    }
  }

  tags = local.tags
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.18"

  name = local.cluster_name
  cidr = local.vpc_cidr

  azs             = ["${local.region}a", "${local.region}b"]
  private_subnets = local.vpc_private_subnets
  public_subnets  = local.vpc_public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }

  tags = local.tags
}
