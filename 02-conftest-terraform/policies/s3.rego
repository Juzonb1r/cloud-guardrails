package security.s3

deny[msg] {
  some i
  input.resource_changes[i].type == "aws_s3_bucket"
  bucket := input.resource_changes[i]
  bucket.change.after.acl == "public-read"
  msg := sprintf("S3 bucket %v cannot be public-read", [bucket.address])
}
