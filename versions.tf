terraform {
  # https://support.hashicorp.com/hc/en-us/articles/360021185113-Support-Period-and-End-of-Life-EOL-Policy
  # https://endoflife.date/terraform
  required_version = ">= 1.12.0"

  required_providers {
    # https://registry.terraform.io/providers/hashicorp/aws/latest
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    # https://registry.terraform.io/providers/hashicorp/kubernetes/latest
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }

    # https://registry.terraform.io/providers/hashicorp/null/latest
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }

    # https://registry.terraform.io/providers/hashicorp/tls/latest
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
  }
}
