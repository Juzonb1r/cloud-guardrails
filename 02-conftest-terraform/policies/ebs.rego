package security.ebs

deny[msg] {
  some i
  input.resource_changes[i].type == "aws_ebs_volume"
  v := input.resource_changes[i]
  not v.change.after.encrypted
  msg := sprintf("EBS volume %v must be encrypted", [v.address])
}
