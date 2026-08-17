# Data Room — infrastructure

Terraform for the AWS side: the bucket documents live in, and the identity the API uses to
sign URLs for it.

The project's design decisions live in the
**[dataroom-api README](https://github.com/GrandMasterX/dataroom-api)**, which is the entry
point.

## What is here, and what is not

**In Terraform:** the documents bucket with its CORS, encryption, public-access block and
lifecycle rules; the IAM identity and its least-privilege policy; the bucket that stores
Terraform state.

**Not in Terraform, deliberately:** deploying the API and the web app. Both platforms deploy
from a git push, and wrapping that would add moving parts without adding control. Saying so
here is better than leaving a gap for someone to assume the state file describes everything
that exists.

## Layout

```
bootstrap/                    creates the state bucket (local state — see below)
modules/
  documents_bucket/           the bucket and everything that makes uploads work
  s3_access_policy/           the permissions, with no opinion about who holds them
  app_identity_user/          an IAM user, for platforms that cannot assume a role
envs/prod/                    composes the modules
```

The access policy is its own module on purpose. Moving the API into AWS means attaching the
same policy to a role instead of a user — a change of principal, not a second copy of the
permissions, which would drift the first time the list changes.

## Applying it

```bash
# Once: the bucket that holds state cannot store its own state remotely.
cd bootstrap
terraform init
terraform apply -var state_bucket_name=dataroom-tfstate-<suffix>

# Then, for real infrastructure:
cd ../envs/prod
# put the bucket name into backend.tf
terraform init
cp terraform.tfvars.example terraform.tfvars   # your app's origins
terraform apply
terraform output -raw s3_secret_access_key     # into the API's environment
```

Needs credentials with S3 and IAM permissions scoped to `dataroom-*`; the setup notes in the
main project list the exact policy.

`bootstrap/`'s local state file is not committed. Losing it is recoverable rather than an
emergency — the stack creates one bucket whose name is known, so
`terraform import aws_s3_bucket.state <name>` brings it back. That is why the stack is kept
deliberately tiny.

## Decisions that are easy to get wrong

**No rule denying unencrypted uploads.** A browser PUT sends no encryption header, so such a
statement turns every upload into a 403 while the bucket's default encryption already encrypts
the object — hardening that breaks the product and protects nothing.

**CORS is a product requirement, not an operational detail.** The browser uploads directly to
the bucket; a missing origin breaks uploading with an error that looks nothing like a storage
problem.

**No `s3:ListBucket`.** Garbage collection works from database rows — the queue of keys from
deleted documents and the record of unfinished uploads — so the application never enumerates
the bucket. Granting it "just in case" would widen what a leaked credential can read for no
working feature.

**Bucket versioning is off.** Document versions are a domain concept with a number, an author
and a date, and they live in the database. Bucket versioning would add a second, invisible
history and make deletion behave differently through delete markers.

**Secrets in state are acknowledged, not hidden.** An access key's secret lands in state in
the clear — that is how the resource works. It is why the state bucket is private, encrypted
and versioned, and why running the API inside AWS with an assumed role is the better end
state: there is no static key to store. Rotation is
`terraform apply -replace=module.app_identity.aws_iam_access_key.app`.

## CI

Formatting and validation on every push, with `-backend=false` so validation needs no
credentials and never touches remote state. Applying stays a deliberate human action.
