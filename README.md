# terraform-aws-api-auth-proxy
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

A terraform module to api authorization via OAuth2 Authorization Code Flow using API Gateway and Lambda


## Features

When designing this module, we've made some decisions about technologies and configuration that might not apply to all use cases. In doing so, we've applied the following principles, in this order:

- __High availability and recovery__. All components are meant to be highly available and provide backups so that important data can be recovered in case of a failure. Database back-ups are activated, and versioning is enabled for the S3 bucket.
- __Least privilege__. We've created dedicated security groups and IAM roles, and restricted traffic/permissions to the minimum necessary to run MLflow.
- __Smallest maintenance overhead__. We've chosen serverless technologies like Fargate and Aurora Serverless to minimize the cost of ownership of an MLflow cluster.
- __Smallest cost overhead__. We've tried to choose technologies that minimize costs, under the assumption that MLflow will be an internal tool that is used during working hours, and with a very lightweight use of the database.
- __Private by default__. As of version 1.9.1, MLflow doesn't provide native authentication/authorization mechanisms. When using the default values, the module will create resources that are not exposed to the Internet. Moreover, the module provides server-side encryption for the S3 bucket and the database through different KMS keys.
- __Flexibility__. Where possible, we've tried to make this module usable under different circumstances. For instance, you can use it to deploy MLflow to a private VPN and access it within a VPN, or you can leverage ALB's integration with Cognito/OIDC to allow users to access MLflow from your SSO solution.


## Usage

To use this module, you can simply:

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
