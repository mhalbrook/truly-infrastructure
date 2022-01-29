output "name_server_record_values" {
  value = aws_route53_record.name_servers.*.records
}