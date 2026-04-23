# 1. VPC & Subnets
resource "google_compute_network" "ai_vpc" {
  name                    = "ai-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.ai_vpc.id
}

# 2. Cloud NAT & Cloud Router
resource "google_compute_router" "router" {
  name    = "ai-router"
  region  = var.region
  network = google_compute_network.ai_vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "ai-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# 3. Firewall Rules
# Allow IAP SSH
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.ai_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"] # IAP IP range
  target_tags   = ["ai-node"]
}

# Allow Health Check from Load Balancer
resource "google_compute_firewall" "allow_health_check" {
  name    = "allow-health-check"
  network = google_compute_network.ai_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["8000"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"] # GCP Load Balancer Healthcheck IP ranges
  target_tags   = ["ai-node"]
}

# 4. GPU Node (Compute Engine)
data "google_compute_image" "deep_learning" {
  family  = "pytorch-2-9-cu129-ubuntu-2204-nvidia-580"
  project = "deeplearning-platform-release"
}

resource "google_compute_instance" "gpu_node" {
  name         = "ai-gpu-node"
  machine_type = "g2-standard-4"
  zone         = var.zone
  tags         = ["ai-node"]

  guest_accelerator {
    type  = "nvidia-l4"
    count = 1
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "TERMINATE"
  }

  boot_disk {
    initialize_params {
      image = data.google_compute_image.deep_learning.self_link
      size  = 150
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.self_link
    # No access_config means no external IP -> Private Subnet
  }

  metadata = {
    install-nvidia-driver = "True"
  }

  metadata_startup_script = templatefile("${path.module}/startup.sh", {
    hf_token = var.hf_token
    model_id = var.model_id
  })

  service_account {
    scopes = ["cloud-platform"]
  }
}

# 5. Load Balancer (External HTTP)
resource "google_compute_health_check" "ai_health_check" {
  name = "ai-health-check"

  timeout_sec         = 5
  check_interval_sec  = 30
  healthy_threshold   = 2
  unhealthy_threshold = 2

  http_health_check {
    port         = 8000
    request_path = "/health"
  }
}

# Unmanaged Instance Group for the single VM
resource "google_compute_instance_group" "ai_ig" {
  name        = "ai-instance-group"
  description = "Instance group for AI node"
  zone        = var.zone
  instances   = [google_compute_instance.gpu_node.self_link]

  named_port {
    name = "http"
    port = 8000
  }
}

resource "google_compute_backend_service" "ai_backend_service" {
  name                  = "ai-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.ai_health_check.id]

  backend {
    group = google_compute_instance_group.ai_ig.self_link
  }
}

resource "google_compute_url_map" "ai_url_map" {
  name            = "ai-url-map"
  default_service = google_compute_backend_service.ai_backend_service.id
}

resource "google_compute_target_http_proxy" "ai_http_proxy" {
  name    = "ai-http-proxy"
  url_map = google_compute_url_map.ai_url_map.id
}

resource "google_compute_global_forwarding_rule" "ai_forwarding_rule" {
  name                  = "ai-forwarding-rule"
  target                = google_compute_target_http_proxy.ai_http_proxy.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL"
}
