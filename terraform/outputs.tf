output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "app_backend_api_gateway_endpoint" {
  value = aws_apigatewayv2_api.backend.api_endpoint
}
