output "s3_bucket" {
  description = "Set as S3_BUCKET on the API."
  value       = module.documents_bucket.bucket
}

output "s3_region" {
  value = var.region
}

output "s3_access_key_id" {
  description = "Set as S3_ACCESS_KEY_ID on the API."
  value       = module.app_identity.access_key_id
}

/**
 * Read with `terraform output -raw s3_secret_access_key`.
 *
 * Marked sensitive so it does not appear in plan output or CI logs. It is still in state —
 * see the note in the app_identity_user module — which is why the state bucket is private and
 * encrypted.
 */
output "s3_secret_access_key" {
  value     = module.app_identity.secret_access_key
  sensitive = true
}
