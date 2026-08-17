/**
 * A static identity for the application, for platforms that cannot assume a role.
 *
 * This is the compromise, not the goal. The API runs on a platform outside AWS, so it has no
 * instance or task role to assume and must present long-lived keys. On a deployment inside
 * AWS this module is replaced by one that attaches the same policy to a role — the policy
 * itself lives in s3_access_policy and does not change, which is what makes that swap a
 * one-line edit rather than a rewrite.
 */

variable "name" {
  description = "Name of the IAM user."
  type        = string
}

variable "policy_json" {
  description = "Policy document from the s3_access_policy module."
  type        = string
}

resource "aws_iam_user" "app" {
  name = var.name
}

# Inline rather than a managed policy: it exists for exactly this user, and an inline policy
# cannot be attached elsewhere by accident.
resource "aws_iam_user_policy" "app" {
  name   = "${var.name}-s3-access"
  user   = aws_iam_user.app.name
  policy = var.policy_json
}

resource "aws_iam_access_key" "app" {
  user = aws_iam_user.app.name
}

output "access_key_id" {
  value = aws_iam_access_key.app.id
}

/**
 * The secret lands in Terraform state in the clear — that is how this resource works, and
 * pretending otherwise would be worse than saying it. It is why the state bucket is private,
 * encrypted and versioned, and why the fully-in-AWS deployment (which needs no static keys at
 * all) is the better end state.
 *
 * Rotation: terraform apply -replace=module.app_identity.aws_iam_access_key.app
 */
output "secret_access_key" {
  value     = aws_iam_access_key.app.secret
  sensitive = true
}
