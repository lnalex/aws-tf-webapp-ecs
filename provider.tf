terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.26.0"
    }
  }

  required_version = "~> 1.6.4"

  backend "s3" {
    bucket = "MY_TFSTATE_BUCKET"
    key = "app/terraform.tfstate"
    region = "ap-southeast-2"
    dynamodb_table = "MY_LOCK_TABLE"
  }
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn = var.deploy_role_arn
  }
}

provider "aws" {
  region = var.region
  alias = "hosted_zone"
  assume_role {
    role_arn = var.cert_config.route53_role
  }
}
