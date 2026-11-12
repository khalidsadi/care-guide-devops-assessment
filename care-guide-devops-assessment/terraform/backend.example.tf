# Configure after creating the S3 bucket and enabling versioning.
# Terraform S3 native lockfile is enabled with use_lockfile (Terraform >= 1.10).
# Replace bucket/key/region with your own values.
terraform {
  backend "s3" {
    bucket       = "REPLACE_WITH_UNIQUE_STATE_BUCKET"
    key          = "care-guide/devops/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
