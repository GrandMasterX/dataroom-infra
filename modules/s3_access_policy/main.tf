/**
 * The permissions the application needs on the documents bucket — and nothing else.
 *
 * This module produces only a policy document. It knows nothing about who the policy will be
 * attached to, and that separation is the point: moving the application from a static IAM
 * user to an assumed role becomes a change of principal, not a second copy of the
 * permissions. Two copies would drift the first time the list changes.
 */

variable "bucket_arn" {
  description = "ARN of the documents bucket."
  type        = string
}

data "aws_iam_policy_document" "app_access" {
  statement {
    sid    = "ReadWriteObjects"
    effect = "Allow"

    # Enumerated rather than s3:*. This list is the effective ceiling on what a leaked
    # credential or a bug in the application can do to the bucket, so it is worth being
    # tedious about.
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]

    resources = ["${var.bucket_arn}/*"]
  }

  statement {
    sid       = "LocateBucket"
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation"]
    resources = [var.bucket_arn]
  }

  # Deliberately absent: s3:ListBucket. Garbage collection works from database rows — the
  # queue of keys from deleted documents and the record of unfinished uploads — so the
  # application never needs to enumerate the bucket. Granting it "just in case" would widen
  # what a leaked credential can read for no working feature.
}

output "json" {
  description = "Policy document to attach to whichever principal runs the application."
  value       = data.aws_iam_policy_document.app_access.json
}
