output "instance_id" {
  value = aws_instance.router.id
}

output "private_ip" {
  value = aws_instance.router.private_ip
}

output "advertised_routes" {
  value = var.advertise_routes
}
