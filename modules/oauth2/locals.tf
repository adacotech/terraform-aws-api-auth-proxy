locals {
  oauth2_authorization_endpoint = var.oauth2_authorization_endpoint != null ? var.oauth2_authorization_endpoint : "${var.oauth2_issuer}authorize"
  oauth2_token_endpoint         = var.oauth2_token_endpoint != null ? var.oauth2_token_endpoint : "${var.oauth2_issuer}oauth/token"
  cookie_token_key              = "_oauth2_token"
  cookie_federation_key         = "_oauth2_federation"
}