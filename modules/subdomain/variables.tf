variable "unique_name" {
  type        = string
  description = "A unique name for this application (e.g. mlflow-team-name)"
}

variable "main_zone_id" {
  type        = string
  description = "main zone id for sub domain"
}

variable "subdomain_name" {
  type        = string
  description = "A unique name for subdomain"
}

