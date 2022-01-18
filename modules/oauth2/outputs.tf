output "authorizer_id" {
  value = aws_apigatewayv2_authorizer.oauth2.id
}

output "signin_integration_id" {
  value = aws_apigatewayv2_integration.signin.id
}
