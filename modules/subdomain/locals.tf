locals {
  subdomain_fullname = "${var.subdomain_name}.${data.aws_route53_zone.main_domain_zone.name}"
}
