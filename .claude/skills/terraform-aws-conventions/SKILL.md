---
name: terraform-aws-conventions
description: Terraform conventions for this project's AWS infrastructure — remote state bootstrap and locking, module boundaries (policy documents separated from the principal they attach to), least-privilege IAM, secrets that unavoidably land in state, required tagging, plan-review discipline, and what deliberately stays outside Terraform. Use whenever you write or review .tf files, add an AWS resource, change a bucket policy or IAM permission, set up or migrate remote state, plan an apply, or decide whether something belongs in IaC at all.
---

# Terraform / AWS conventions

Infrastructure code is reviewed differently from application code: a wrong `apply` can be
unrecoverable, and the feedback loop is minutes long. These rules optimize for "the diff is obviously
safe to apply" over brevity.

## State

- Remote state in S3 with native locking (`use_lockfile = true`, Terraform ≥ 1.10). A separate lock table
  is no longer needed; if you see one proposed, it is a habit from older versions, not a requirement.
- The state bucket cannot be created by the stack that stores state in it. Keep a small `bootstrap/` stack
  with local state that creates it (versioned, encrypted, private, public access blocked). Its local state
  file is never committed, and its README says what to do if it is lost — recreating the bucket by hand is
  a five-minute job, so this is an accepted, documented risk rather than a hidden one.
- One state per environment. Sharing a state across environments means a mistake in one can destroy the
  other, and `plan` output stops being reviewable.

## Module boundaries

Split modules by **what the thing is**, not by what uses it. Concretely: an IAM policy document is one
piece of knowledge, and the principal it is attached to is another. Keeping the document in its own module
means switching from a static-key IAM user to an instance or task role changes one `source` line instead
of copying the permissions into a second module — and copied permissions drift the first time they change.

A module should expose the smallest useful surface: required inputs with no defaults for anything
environment-specific, and outputs limited to what a caller genuinely needs. Every default is a decision the
caller will not notice they inherited.

## IAM

- Enumerate actions; never `s3:*`. The set of granted actions is the effective ceiling on what a leaked
  credential or a bug can do, so it is worth being tedious about.
- Scope resources to specific ARNs, and remember object actions target `arn:.../bucket/*` while bucket
  actions target `arn:.../bucket` — mixing these up produces "works but denies half the calls".
- Grant a permission only when you can name the call that needs it. If a listing permission exists only
  for a garbage-collection job you have not written, remove it until you write the job.
- Prefer a role assumed by the workload over a user with long-lived keys whenever the platform allows it.
  Static keys must be rotatable on demand: know the command before you need it.

## Secrets in state

Some resources put secrets into state by design (an access key's secret, a generated password). That is not
a reason to avoid Terraform for them, but it does mean:

- The state backend is private, encrypted, and versioned, and access is limited to whoever may already read
  those secrets.
- Outputs carrying secrets are marked `sensitive` — this keeps them out of CI logs and plan output.
- Write down how rotation works (`-replace` on the key resource) next to the resource, because rotation is
  needed exactly when nobody has time to work it out.

## Reviewing an apply

Read the plan as a diff, not as a formality. Specifically look for:

- Any `destroy` or `replace` you did not intend, and for replacements, what breaks between destroy and
  create. A bucket or database appearing in that list means stop.
- Changes to a resource you did not touch — usually drift someone made in the console, which the apply is
  about to silently revert.
- Empty diffs on resources you expected to change, which usually means an input is not wired through.

Keep `terraform fmt -check`, `init -backend=false`, `validate` and a linter in CI so that review time is
spent on the plan rather than on formatting.

## Tagging and naming

Set `default_tags` at the provider level (project, environment, managed-by) so every resource is attributable
without repeating tags per resource. Globally-unique names (S3 buckets) get a random suffix rather than a
hand-picked one — a name collision surfaces as a confusing permission error, not as "name taken".

## What stays out of Terraform

Deciding this explicitly is part of the design. Platform deploys that are driven by git push, and one-off
data operations such as seeding, are clearer as documented commands than as IaC that pretends to own them.
Write down in the README which parts are imperative and why, so the next person does not assume the state
file describes everything that exists.

## Verification after apply

`apply` succeeding means the API accepted the configuration, not that the product works. Verify the
properties that matter from the outside: a presigned PUT from a real browser origin (this is the only way to
exercise CORS), a denied request that should be denied, and the resource's own settings read back with the
CLI. Reading the `.tf` file back is not verification of anything.
