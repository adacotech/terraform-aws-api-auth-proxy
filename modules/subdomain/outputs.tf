output "subdomain_fullname" {
  value = local.subdomain_fullname
}

output "apigatewayv2_domain_id" {
  value = aws_apigatewayv2_domain_name.subdomain.id
}
