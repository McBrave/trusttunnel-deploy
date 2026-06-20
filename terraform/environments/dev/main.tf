terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "../../modules/vpc"

  project_name      = var.project_name
  availability_zone = "${var.aws_region}a"
}

module "ec2" {
  source = "../../modules/ec2"

  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_id
  instance_type    = var.instance_type
  ssh_public_key   = var.ssh_public_key
  ssh_allowed_cidr = var.ssh_allowed_cidr
}
