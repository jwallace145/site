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
  # Key:    <environment>/<stack>/terraform.tfstate, so one bucket can hold
  #         every stack of this project, e.g.
  #           prod/live/terraform.tfstate      (this root)
  #           prod/backend/terraform.tfstate   (future API stack)
  backend "s3" {
    bucket       = "jwallace145-site-tfstate"
    key          = "prod/live/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
