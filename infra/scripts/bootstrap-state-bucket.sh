#!/usr/bin/env bash
# Creates the Terraform state bucket for jwall-engineering-site. Run once, by hand,
# before the first `terraform init`. Safe to re-run: every call is idempotent.
#
# The bucket is deliberately outside Terraform (chicken and egg), so this
# script applies the same standard tags Terraform applies everywhere else.
set -euo pipefail

BUCKET="${TF_STATE_BUCKET:-jwall-engineering-site-tfstate}"
REGION="${AWS_REGION:-us-east-1}"

TAGS='TagSet=[
  {Key=Project,Value=jwall-engineering-site},
  {Key=Owner,Value=jwallace145},
  {Key=Environment,Value=prod},
  {Key=ManagedBy,Value=bootstrap-script},
  {Key=Repository,Value=github.com/jwallace145/site},
  {Key=Name,Value='"$BUCKET"'}
]'

echo "Account: $(aws sts get-caller-identity --query Account --output text)"
echo "Bucket:  s3://$BUCKET ($REGION)"

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket exists; ensuring settings."
else
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=$REGION" >/dev/null
  fi
  echo "Created."
fi

aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws s3api put-bucket-ownership-controls --bucket "$BUCKET" \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'

aws s3api put-bucket-tagging --bucket "$BUCKET" --tagging "$TAGS"

# Keep old state versions for 90 days, then expire them. Current state is never expired.
aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" --lifecycle-configuration '{
  "Rules": [{
    "ID": "expire-old-state-versions",
    "Status": "Enabled",
    "Filter": {"Prefix": ""},
    "NoncurrentVersionExpiration": {"NoncurrentDays": 90},
    "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 7}
  }]
}'

echo "Done. State keys live under <environment>/<stack>/terraform.tfstate, e.g. environment=prod/terraform.tfstate."
