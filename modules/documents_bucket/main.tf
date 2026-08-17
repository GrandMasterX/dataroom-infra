/**
 * The bucket holding uploaded documents.
 *
 * Bytes travel between the browser and this bucket directly, using presigned URLs, so its
 * CORS configuration is part of the product working rather than an operational detail.
 */

variable "bucket_name" {
  description = "Globally unique bucket name."
  type        = string
}

variable "allowed_origins" {
  description = "Browser origins permitted to PUT and GET directly."
  type        = list(string)
}

variable "abort_incomplete_uploads_after_days" {
  description = "How long an unfinished multipart upload may linger before being charged for."
  type        = number
  default     = 1
}

resource "aws_s3_bucket" "documents" {
  bucket = var.bucket_name
}

# The product's own access control is the only way in. Nothing here is ever public, and
# "public link" in the product means a token this application checks, not a public object.
resource "aws_s3_bucket_public_access_block" "documents" {
  bucket                  = aws_s3_bucket.documents.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACLs are a legacy mechanism and an extra surface for mistakes; ownership settles every
# object on the bucket owner instead.
resource "aws_s3_bucket_ownership_controls" "documents" {
  bucket = aws_s3_bucket.documents.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Versioning stays off on purpose. Document versions are a domain concept with a number, an
# author and a date, and they live in the database; bucket versioning would add a second,
# invisible history and make deletion behave differently through delete markers.
resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id
  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_cors_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  cors_rule {
    allowed_origins = var.allowed_origins
    allowed_methods = ["PUT", "GET", "HEAD"]
    allowed_headers = ["*"]
    # Without this the browser cannot read the ETag even though the response carries it.
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_uploads_after_days
    }
  }
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [aws_s3_bucket.documents.arn, "${aws_s3_bucket.documents.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Deliberately no statement denying uploads without an encryption header. A browser PUT
  # does not send one, so such a rule turns every upload into a 403 while the bucket's
  # default encryption already encrypts the object — hardening that breaks the product
  # without protecting anything.
}

resource "aws_s3_bucket_policy" "documents" {
  bucket = aws_s3_bucket.documents.id
  policy = data.aws_iam_policy_document.bucket_policy.json

  # A policy applied before public access is blocked would leave a window where a mistake in
  # it is actually reachable.
  depends_on = [aws_s3_bucket_public_access_block.documents]
}

output "bucket" {
  value = aws_s3_bucket.documents.id
}

output "arn" {
  value = aws_s3_bucket.documents.arn
}
