/**
 * Production infrastructure for the Data Room.
 *
 * What is here: the bucket documents live in, and the identity the API uses to sign URLs for
 * it. What is not: the platforms running the API and the web app. Both deploy from a git
 * push, and wrapping that in Terraform would add moving parts without adding control — the
 * README says so plainly rather than leaving the gap for someone to discover.
 */

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = var.region

  # Applied to every resource, so anything created here is attributable without repeating
  # tags per resource.
  default_tags {
    tags = {
      Project   = "dataroom"
      Env       = "prod"
      ManagedBy = "terraform"
    }
  }
}

# Bucket names are globally unique across all of AWS; a hand-picked one collides with a
# stranger's bucket and surfaces as a confusing permission error rather than "name taken".
resource "random_id" "suffix" {
  byte_length = 4
}

module "documents_bucket" {
  source          = "../../modules/documents_bucket"
  bucket_name     = "dataroom-prod-${random_id.suffix.hex}"
  allowed_origins = var.allowed_origins
}

module "s3_access_policy" {
  source     = "../../modules/s3_access_policy"
  bucket_arn = module.documents_bucket.arn
}

module "app_identity" {
  # Swap to ../../modules/app_identity_role when the API runs inside AWS: the policy above is
  # unchanged, and static keys stop existing.
  source      = "../../modules/app_identity_user"
  name        = "dataroom-api-prod"
  policy_json = module.s3_access_policy.json
}
