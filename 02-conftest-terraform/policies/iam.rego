package security.iam

deny[msg] {
  some i
  input.resource_changes[i].type == "aws_iam_policy"
  p := input.resource_changes[i]
  some s
  s := p.change.after.policy.Statement[_]
  s.Action == "*"
  msg := sprintf("IAM policy %v must not use Action *", [p.address])
}
