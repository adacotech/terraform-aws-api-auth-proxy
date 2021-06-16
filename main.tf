module "subdomain" {
  source         = "./modules/subdomain"
  main_zone_id   = var.main_zone_id
  subdomain_name = var.subdomain_name
  unique_name    = var.unique_name
}

module "authorizer" {
  source                        = "./modules/oauth2"
  api_id                        = aws_apigatewayv2_api.api.id
  unique_name                   = var.unique_name
  oauth2_issuer                 = var.oauth2_issuer
  oauth2_client_id              = var.oauth2_client_id
  oauth2_audience               = var.oauth2_audience
  oauth2_scope                  = var.oauth2_scope
  oauth2_authorization_endpoint = var.oauth2_authorization_endpoint
  oauth2_token_endpoint         = var.oauth2_token_endpoint
  base_uri                      = "https://${module.subdomain.subdomain_fullname}"
}

resource "aws_cloudwatch_log_group" "apigateway" {
  name              = "/aws/apigateway/${var.unique_name}"
  retention_in_days = var.service_log_retention_in_days
  tags              = var.tags
}

resource "aws_apigatewayv2_api" "api" {
  name                         = "${var.unique_name}-api"
  protocol_type                = "HTTP"
  disable_execute_api_endpoint = true
}

resource "aws_apigatewayv2_stage" "api" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigateway.arn
    format          = "$context.identity.sourceIp,$context.requestTime,$context.httpMethod,$context.routeKey,$context.protocol,$context.status,$context.responseLength,$context.requestId"
  }
}

resource "aws_apigatewayv2_integration" "api" {
  api_id             = aws_apigatewayv2_api.api.id
  integration_type   = "HTTP_PROXY"
  connection_id      = aws_apigatewayv2_vpc_link.api.id
  connection_type    = "VPC_LINK"
  integration_method = "ANY"
  integration_uri    = var.load_balancer_listener_arn
}


resource "aws_apigatewayv2_route" "api" {
  api_id             = aws_apigatewayv2_api.api.id
  operation_name     = "ConnectRoute"
  target             = "integrations/${aws_apigatewayv2_integration.api.id}"
  route_key          = "$default"
  authorization_type = "CUSTOM"
  authorizer_id      = module.authorizer.authorizer_id
}


resource "aws_apigatewayv2_api_mapping" "api" {
  api_id      = aws_apigatewayv2_api.api.id
  domain_name = module.subdomain.apigatewayv2_domain_id
  stage       = aws_apigatewayv2_stage.api.id
}

resource "aws_security_group" "api" {
  name        = "${var.unique_name}-sg"
  description = "SG for vpc link"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_apigatewayv2_vpc_link" "api" {
  name               = "${var.unique_name}-vpc-link"
  security_group_ids = [aws_security_group.api.id]
  subnet_ids         = var.service_subnet_ids

  tags = var.tags
}
