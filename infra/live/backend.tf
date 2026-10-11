terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state in S3 with native lockfile locking (no DynamoDB table).
  #
  # Bucket: created once by infra/scripts/bootstrap-state-bucket.sh.
  # Key:    environment=<env>/terraform.tfstate. Terraform writes the lock
  #         beside it as terraform.tfstate.tflock while a write is in flight.
  #
  # Backend blocks cannot reference variables, so these literals are repeated
  # in local.terraform_state below for the plan role. Keep them in sync.
  backend "s3" {
    bucket       = "jwallace145-site-tfstate"
    key          = "environment=prod/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

locals {
  terraform_state = {
    bucket = "jwallace145-site-tfstate"
    key    = "environment=prod/terraform.tfstate"
  }
}
