variable "main_zone_id" {
  type        = string
  description = "main zone id for apigateway domain"
  default     = null
}

variable "unique_name" {
  type        = string
  description = "A unique name for this application (e.g. org-team-name)"
}

variable "subdomain_name" {
  type        = string
  description = "A unique name for subdomain (e.g. org-team-name)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "AWS Tags common to all the resources created"
}

variable "vpc_id" {
  type        = string
  description = "AWS VPC to deploy this"
}

variable "integration_uri" {
  type        = string
  description = "What this proxy integrate to (e.g. load_balancer_listener_arn)"
}

variable "service_subnet_ids" {
  type        = list(string)
  description = "List of subnets where the service will be deployed"
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
  default     = null
}

variable "oauth2_token_endpoint" {
  type        = string
  description = "token endpoint"
  default     = null
}

variable "service_log_retention_in_days" {
  type        = number
  description = "cloudwatch log retention in days"
  default     = 7
}