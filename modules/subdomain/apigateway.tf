resource "aws_apigatewayv2_domain_name" "subdomain" {
  domain_name = local.subdomain_fullname

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.main_cert.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

