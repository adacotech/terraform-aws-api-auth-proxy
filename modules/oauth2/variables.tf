variable "unique_name" {
  type        = string
  description = "A unique name for this application (e.g. team-name)"
}

variable "api_id" {
  type        = string
  description = "target apigateway id"
}

variable "oauth2_client_id" {
  type        = string
  description = "oauth2 client id"
}

variable "oauth2_audience" {
  type        = string
  description = "oauth2 audience"
}

variable "oauth2_issuer" {
  type        = string
  description = "oauth2 issuer"
}

variable "oauth2_scope" {
  type        = string
  description = "oauth2 scope"
}

variable "oauth2_authorization_endpoint" {
  type        = string
  description = "authorization endpoint"
}

variable "oauth2_token_endpoint" {
  type        = string
  description = "token endpoint"
}

variable "base_uri" {
  type        = string
  description = "api gateway integration base uri"
}