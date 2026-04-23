output "alb_ip_address" {
  description = "The public IP address of the External Load Balancer"
  value       = google_compute_global_forwarding_rule.ai_forwarding_rule.ip_address
}

output "endpoint_url" {
  description = "The AI endpoint URL"
  value       = "http://${google_compute_global_forwarding_rule.ai_forwarding_rule.ip_address}/v1/completions"
}

output "gpu_private_ip" {
  description = "The private IP address of the GPU Node"
  value       = google_compute_instance.gpu_node.network_interface[0].network_ip
}
