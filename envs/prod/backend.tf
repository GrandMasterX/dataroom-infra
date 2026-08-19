terraform {
  /**
   * Remote state in S3 with native locking.
   *
   * `use_lockfile` replaces the DynamoDB table that older setups used for locks; requiring
   * Terraform 1.10 buys the removal of a whole resource whose only job was to guard applies.
   *
   * The bucket is created by the bootstrap stack. Fill in its name and run
   * `terraform init` here.
   */
  backend "s3" {
    bucket       = "dataroom-tfstate-9382bf2e"
    key          = "prod/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
