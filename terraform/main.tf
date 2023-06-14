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


# API Gateway

resource "aws_apigatewayv2_api" "backend" {
  name          = "${var.env}-backend"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "backend" {
  api_id      = aws_apigatewayv2_api.backend.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "backend" {
  api_id                 = aws_apigatewayv2_api.backend.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.backend.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "backend" {
  api_id    = aws_apigatewayv2_api.backend.id
  route_key = "ANY /"
  # a little funky how we have to prefix "integrations", but I couldn't find a fully qualified var to reference
  target = "integrations/${aws_apigatewayv2_integration.backend.id}"
}

resource "aws_lambda_permission" "backend_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.backend.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource within the API Gateway "REST API".
  source_arn = "${aws_apigatewayv2_api.backend.execution_arn}/*/*"
}


# EVENT BRIDGE TRIGGER

# TODO timeout?
resource "aws_cloudwatch_event_rule" "checkin_lambda_event_rule" {
  name                = "${var.env}-checkin-lambda-event-rule"
  schedule_expression = "rate(2 minutes)"
}

resource "aws_cloudwatch_event_target" "checkin_lambda_target" {
  arn  = aws_lambda_function.checkin.arn
  rule = aws_cloudwatch_event_rule.checkin_lambda_event_rule.name
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_rw_fallout_retry_step_deletion_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.checkin.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.checkin_lambda_event_rule.arn
}
