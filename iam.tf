resource "aws_iam_role" "authenticated" {
  name = "${var.name}-AUTH-ROLE"

  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
    {
    "Effect": "Allow",
    "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
        "StringEquals": {
        "cognito-identity.amazonaws.com:aud": "${aws_cognito_identity_pool.identity_pool.id}"
        },
        "ForAnyValue:StringLike": {
        "cognito-identity.amazonaws.com:amr": "authenticated"
        }
    }
    }
]
}
EOF

}

resource "aws_iam_role_policy" "authenticated" {
  name = "authenticated_policy"
  role = aws_iam_role.authenticated.id

  policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
  {
  "Effect": "Allow",
  "Action": [
      "mobileanalytics:PutEvents",
      "cognito-sync:*"
  ],
  "Resource": [
      "*"
  ]
  }
]
}
EOF
}

resource "aws_iam_role" "unauthenticated" {
  name = "${var.name}-UNAUTH-ROLE"

  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
  {
  "Effect": "Allow",
  "Principal": {
      "Federated": "cognito-identity.amazonaws.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
      "StringEquals": {
      "cognito-identity.amazonaws.com:aud": "${aws_cognito_identity_pool.identity_pool.id}"
      },
      "ForAnyValue:StringLike": {
      "cognito-identity.amazonaws.com:amr": "unauthenticated"
      }
  }
  }
]
}
EOF
}

resource "aws_iam_role_policy" "unauthenticated" {
  name = "authenticated_policy"
  role = aws_iam_role.authenticated.id

  policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
  {
  "Effect": "Allow",
  "Action": [
      "mobileanalytics:PutEvents",
      "cognito-sync:*"
  ],
  "Resource": [
      "*"
  ]
  }
]
}
EOF
}

resource "aws_cognito_identity_pool_roles_attachment" "identity_pool" {
  identity_pool_id = aws_cognito_identity_pool.identity_pool.id
  roles = {
    "authenticated" = aws_iam_role.authenticated.arn
    "unauthenticated" = aws_iam_role.unauthenticated.arn
  }
}

resource "aws_cloudwatch_log_group" "es_cloudwatch_log_group" {

  for_each = { for k, v in var.log_publishing_options :
    k => v if var.enabled && lookup(v, "enabled", false) && lookup(v, "cloudwatch_log_group_name", null) != null
  }

  name              = each.value["cloudwatch_log_group_name"]
  retention_in_days = lookup(each.value, "log_publishing_options_retention", var.log_publishing_options_retention)
  tags              = merge(lookup(each.value, "tags", null), var.tags)
}

resource "aws_cloudwatch_log_resource_policy" "es_aws_cloudwatch_log_resource_policy" {
  count       = var.enabled && var.cloudwatch_log_enabled ? 1 : 0
  policy_name = "${var.domain_name}-policy"

  policy_document = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": [
        "logs:PutLogEvents",
        "logs:PutLogEventsBatch",
        "logs:CreateLogStream"
      ],
      "Resource": "arn:aws:logs:*"
    }
  ]
}
CONFIG
}

# Service-linked role to give Amazon ES permissions to access your VPC
resource "aws_iam_service_linked_role" "es" {
  count            = var.enabled && var.create_service_link_role ? 1 : 0
  aws_service_name = "es.amazonaws.com"
  description      = "Service-linked role to give Amazon ES permissions to access your VPC"
}
