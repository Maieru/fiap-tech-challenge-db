terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "6.52.0" }
    random = { source = "hashicorp/random", version = "~> 3.7" }
    tls    = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}
provider "aws" {
  region = var.aws_region
  default_tags { tags = { Project = "fiap-tech-challenge" } }
}
