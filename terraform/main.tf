data "aws_caller_identity" "current" {}

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

resource "aws_lambda_function" "checkin" {
  function_name = "${var.env}-checkin"
  timeout       = 5 # seconds
  image_uri     = "${aws_ecr_repository.app.repository_url}:${var.env}"
  package_type  = "Image"

  role = aws_iam_role.lambda.arn

  environment {
    variables = {
      ENVIRONMENT = var.env
    }
  }
}
