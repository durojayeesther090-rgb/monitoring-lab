output "monitor_public_ip" {
  value = aws_instance.monitor.public_ip
}

output "target_public_ip" {
  value = aws_instance.target.public_ip
}

output "grafana_url" {
  value = "http://${aws_instance.monitor.public_ip}:3000"
}

output "prometheus_url" {
  value = "http://${aws_instance.monitor.public_ip}:9090"
}
