/**
 * Creates the bucket that holds Terraform state for every other stack.
 *
 * It has to exist before anything can store state remotely, so this one stack keeps its state
 * locally — the chicken-and-egg that every remote backend has. Applied once, and its local
 * state file is not committed.
 *
 * Losing that file is recoverable and not an emergency: this stack creates a single bucket
 * whose name is known, so it can be imported again with
 *   terraform import aws_s3_bucket.state <bucket-name>
 * That is the reason this stack is kept deliberately tiny.
 */

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "region" {
  description = "AWS region for the state bucket."
  type        = string
  default     = "eu-west-1"
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket."
  type        = string
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "dataroom"
      Component = "terraform-state"
      ManagedBy = "terraform"
    }
  }
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# State contains secrets by design — an access key's secret, for one — so versioning is not
# about convenience here: it is what makes a bad apply recoverable without hand-editing.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

output "state_bucket" {
  value       = aws_s3_bucket.state.id
  description = "Put this in envs/prod/backend.tf."
}
