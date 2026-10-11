terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
      # CloudFront only accepts ACM certificates from us-east-1, so the caller
      # passes a second provider: providers = { aws = aws, aws.us_east_1 = ... }
      configuration_aliases = [aws.us_east_1]
    }
  }
}
