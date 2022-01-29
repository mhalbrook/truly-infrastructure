resource "aws_route53_zone" "halbromr" {
  provider = aws
  name     = var.domain
}

resource "aws_route53_record" "name_servers" {
  provider        = aws
  allow_overwrite = true
  name            = var.domain
  ttl             = 30
  type            = "NS"
  zone_id         = aws_route53_zone.halbromr.zone_id

  records = [
    aws_route53_zone.halbromr.name_servers.0,
    aws_route53_zone.halbromr.name_servers.1,
    aws_route53_zone.halbromr.name_servers.2,
    aws_route53_zone.halbromr.name_servers.3,
  ]
}