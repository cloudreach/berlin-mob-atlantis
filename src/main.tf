
provider "aws" {
  region = "eu-central-1"
}

terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

resource "aws_iam_policy" "berlin-mob-atlantis-policy" {
  name        = "berlin-mob-atlantis-policy"
  description = "Policy to test resource provisioning"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["ec2:Describe*", "ec2:List*"]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

output "policy_arn" {
  value = aws_iam_policy.berlin-mob-atlantis-policy.id
}






















