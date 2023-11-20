data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:ecs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      ]
    }
  }
}

locals {
  # https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
  elb_log_accounts = {
    us-east-1 = "127311923021"
    ap-southeast-2 = "783225319266"
    # add more as needed
  }
}
