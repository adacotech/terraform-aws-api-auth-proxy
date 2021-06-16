resource "aws_acm_certificate" "main_cert" {
  domain_name       = local.subdomain_fullname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.unique_name}-main-ssl"
  }
}

resource "aws_route53_record" "main_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  name    = each.value.name
  type    = each.value.type
  zone_id = data.aws_route53_zone.main_domain_zone.zone_id
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "main_cert" {
  certificate_arn         = aws_acm_certificate.main_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.main_cert_validation : record.fqdn]
}

data "aws_route53_zone" "main_domain_zone" {
  zone_id = var.main_zone_id
}

resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.main_domain_zone.zone_id
  name    = local.subdomain_fullname
  type    = "A"

  dynamic "alias" {
    for_each = {
      for conf in aws_apigatewayv2_domain_name.subdomain.domain_name_configuration : conf.target_domain_name => {
        zone_id = conf.hosted_zone_id
      }
    }

    content {
      name                   = alias.key
      zone_id                = alias.value["zone_id"]
      evaluate_target_health = false
    }
  }
}

