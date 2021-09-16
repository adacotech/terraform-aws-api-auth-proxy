# terraform-aws-api-auth-proxy
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

A terraform module to api authorization via OAuth2 Authorization Code Flow using API Gateway and Lambda Authorizer.

## Features

- Low cost
This module is implemented on a serverless architecture, resulting in infinitely low operational costs.

- High security
Designed based on the OAuth2 Authorization Code Flow with PKCE, this module does not store credentials. This allows access to internal servers while maintaining a high level of security.

- Flexibility
By using the private integration of API Gateway, authorization processing is added to various targets such as ALB and lambda. It is ideal for applications that grant OAuth2 authorization to internal servers that do not have an authentication.

## Usage

```hcl
module "api_authorizer" {
  source  = ""
  version = "0.1.0"

  unique_name                       = "unique-name"
  subdomain_name                    = "subdomain"
  main_zone_id                      = "ROUTE53MAINZONE"
  vpc_id                            = "vpc-00112233445566"
  integration_uri                   = "arn:aws:elasticloadbalancing:us-east-1:00112233445566:listener/app/alb/112233445566/aabbccddeeff"
  service_subnet_ids                = ["subnet-001122334455", "subnet-112233445566"]
  oauth2_client_id                  = "clientid"
  oauth2_audience                   = "https://subdomain.foo.com"
  oauth2_issuer                     = "https://issur.auth0.com/"
  oauth2_scope                      = "read:org"
  oauth2_authorization_endpoint     = null
  oauth2_token_endpoint             = null
}
```


## Roadmap

- TBD


## Contributors

Everybody is welcome to contribute ideas and PRs to this repository. We don't have any strict contribution guidelines. Follow your best common sense and have some patience with us if we take a few days to answer.
