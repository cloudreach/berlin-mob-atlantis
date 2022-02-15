terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# we can remove the secret and store the token in SSM Parameter /atlantis/github/user/token 
# or another param in SSM, whose name can be provided to the module with 
# atlantis_github_user_token_ssm_parameter_name 
# (see https://registry.terraform.io/modules/terraform-aws-modules/atlantis/aws/latest?tab=inputs)
data "aws_secretsmanager_secret_version" "github_creds" {
  secret_id = "atlantisGithubCreds"
}

locals {
  github_creds = jsondecode(
    data.aws_secretsmanager_secret_version.github_creds.secret_string
  )
}

module "atlantis" {
  source  = "terraform-aws-modules/atlantis/aws"
  version = "~> 3.0"

  name = "atlantis"

  # VPC
  # get from data
  vpc_id             = "vpc-07af036bff338e248"
  private_subnet_ids = ["subnet-0c0e546b81ef587ea", "subnet-0f6ec8e8327d38def", "subnet-07b06e17257612459"]
  public_subnet_ids  = ["subnet-0d82017d00f918f1a", "subnet-07c39f33c19887fba", "subnet-0ee525959af0cc838"]

  # DNS (without trailing dot)
  # get from data
  route53_zone_name = "example.io"

  # ACM (SSL certificate) - Specify ARN of an existing certificate or new one will be created and validated using Route53 DNS
  # omit to create
  # certificate_arn = "arn:aws:acm:eu-west-1:135367859851:certificate/70e008e1-c0e1-4c7e-9670-7bb5bd4f5a84"

  # Atlantis server configuration
  custom_environment_variables = [
    {
      "name" : "ATLANTIS_REPO_CONFIG_JSON",
      "value" : jsonencode(yamldecode(file("${path.module}/server-atlantis.yaml"))),
    },
    {
      "name" : "ATLANTIS_GH_HOSTNAME",
      "value" : "github.platform.vwfs.io",
    }
  ]
  # Atlantis
  atlantis_github_user         = local.github_creds.user
  atlantis_github_user_token   = local.github_creds.user_token
  atlantis_repo_allowlist      = ["https://github.com/cloudreach/berlin-mob-atlantis"]
  atlantis_allowed_repo_names  = ["cloudreach/berlin-mob-atlantis"]
  allow_github_webhooks        = "true"
  allow_unauthenticated_access = "true"
  # later, to allow repo level configuration - then you must have it!
  # allow_repo_config = "true"
}

resource "aws_iam_policy" "ecs_task_policy" {
  name        = "poc_atlantis_ecs_task_policy"
  description = "Allow access to poc_atlantis state bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "sgaccess",
        "Effect" : "Allow",
        "Action" : [
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeTags"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "statefileaccess",
        "Effect" : "Allow",
        "Action" : "s3:*",
        "Resource" : [
          "arn:aws:s3:::poc-atlantis",
          "arn:aws:s3:::poc-atlantis/*"
        ]
      },
      {
        "Sid" : "elb",
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:*"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "ssm",
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue",
          "ssm:GetParameter",
          "ssm:DescribeParameter",
          "ssm:DescribeParameters"
        ],
        "Resource" : [
          "arn:aws:secretsmanager:*:012345678910:secret:*",
          "arn:aws:ssm:eu-central-1:012345678910:parameter/atlantis*"
        ]
      },
      {
        "Sid" : "acm",
        "Effect" : "Allow",
        "Action" : [
          "acm:DescribeCertificate",
          "acm:ListTagsForCertificate"
        ],
        "Resource" : [
          "arn:aws:acm:*:012345678910:certificate/*",
        ]
      },
      {
        "Sid" : "iam",
        "Effect" : "Allow",
        "Action" : [
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetRole"
        ],
        "Resource" : [
          "arn:aws:iam::012345678910:*",
        ]
      },
      {
        "Sid" : "ecscluster",
        "Effect" : "Allow",
        "Action" : [
          "ecs:DescribeClusters"
        ],
        "Resource" : [
          "arn:aws:ecs:eu-central-1:012345678910:*",
        ]
      },
      {
        "Sid" : "r53",
        "Effect" : "Allow",
        "Action" : [
          "route53:ListHostedZones",
          "route53:GetHostedZone",
          "route53:ListTagsForResource"
        ],
        "Resource" : [
          "*"
        ]
      },
      {
        "Sid" : "cw",
        "Effect" : "Allow",
        "Action" : [
          "logs:DescribeLogGroups",
          "logs:ListTagsLogGroup"
        ],
        "Resource" : "*"
      }

    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = module.atlantis.task_role_name
  policy_arn = aws_iam_policy.ecs_task_policy.id
}
output "atlantis_url" {
  value = module.atlantis.atlantis_url
}
