data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# TODO a little bit of funkiness promoting artifacts if there's a repo per env
resource "aws_ecr_repository" "app" {
  name = "inception-health/app"

  # TODO enable encryption
  #encryption_configuration = {
  #  encryption_type = "KMS"
  #  kms_key =
  #}

  # TODO should be enabled
  #image_scanning_configuration {
  #  scan_on_push = true
  #}
}

resource "aws_dynamodb_table" "checkin" {
  name           = "${var.env}-checkin"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # TODO across the application
  #tags = {
  #  Name        =
  #  Environment =
  #}
}

# TODO need logging
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function#cloudwatch-logging-and-permissions
resource "aws_lambda_function" "checkin" {
  function_name = "${var.env}-checkin"
  timeout       = 5 # seconds
  image_uri     = "${aws_ecr_repository.app.repository_url}:${var.env}"
  package_type  = "Image"
  role          = aws_iam_role.lambda.arn

  image_config {
    command = ["index.checkin"]
  }

  environment {
    variables = {
      ENVIRONMENT       = var.env
      DYNAMO_TABLE_NAME = aws_dynamodb_table.checkin.name
      REGION            = data.aws_region.current.name
    }
  }
}

resource "aws_lambda_function" "backend" {
  function_name = "${var.env}-backend"
  timeout       = 5 # seconds
  image_uri     = "${aws_ecr_repository.app.repository_url}:${var.env}"
  package_type  = "Image"
  role          = aws_iam_role.lambda.arn

  image_config {
    command = ["index.backend"]
  }

  environment {
    variables = {
      ENVIRONMENT       = var.env
      DYNAMO_TABLE_NAME = aws_dynamodb_table.checkin.name
      REGION            = data.aws_region.current.name
    }
  }
}
