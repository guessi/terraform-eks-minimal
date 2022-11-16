terraform {
  required_version = "~> 1.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.33"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
  }
}
