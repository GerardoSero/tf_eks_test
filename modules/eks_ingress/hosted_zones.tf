resource "aws_route53_zone" "ingress_dns_zone" {
  for_each = toset(var.external_dns.dns_zones)

  name    = each.key
  comment = "Something useful"
}