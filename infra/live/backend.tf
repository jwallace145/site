terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state in S3 with native lockfile locking (no DynamoDB table).
  # Bucket and region are supplied at init so nothing account-specific is
  # committed:
  #   terraform init \
  #     -backend-config="bucket=<state-bucket>" \
  #     -backend-config="region=<region>"
  backend "s3" {
    key          = "jwallace145-site/live/terraform.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
