variable "region" {
  description = "AWS region. Matches where the database lives, to keep uploads and reads close."
  type        = string
  default     = "eu-west-1"
}

variable "allowed_origins" {
  description = <<-DESC
    Browser origins allowed to upload and download directly.

    This is not a formality: the browser PUTs straight to the bucket, so a missing origin
    here breaks uploading with a CORS error that looks nothing like a storage problem. Local
    development is included because the same bucket can be pointed at from a laptop when
    reproducing something.
  DESC
  type        = list(string)
}
