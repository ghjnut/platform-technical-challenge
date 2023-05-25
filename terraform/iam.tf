data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.env}-lambda_assume_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# TODO lock-down, see below
data "aws_iam_policy" "dynamodb_full_access" {
  name = "AmazonDynamoDBFullAccess"
}

resource "aws_iam_policy_attachment" "lambda_dynamodb_full_access" {
  name       = "${var.env}-lambda_dynamodb_full_access"
  roles      = [aws_iam_role.lambda.name]
  policy_arn = data.aws_iam_policy.dynamodb_full_access.arn
}

#resource "aws_iam_policy_document" "checkin" {
#  statement {
#    effect = "Allow"
#    actions = ["dynamodb:DescribeTable"]
#    # TODO lock-down to specific table
#    resource = "*"
#  }
#}
