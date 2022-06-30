
resource "google_project_service" "services" {
  for_each = toset(var.services)
  service  = each.value
}

resource "google_dns_managed_zone" "default" {
  name        = "week7"
  dns_name    = "week7challenge.tk."
  description = "Week 7 DNS"

  visibility = "public"
}

# reserved IP address
resource "google_compute_global_address" "default" {
  name         = "load-balancer-ip"
  address_type = "EXTERNAL"
}

resource "google_dns_record_set" "frontend" {
  name = "www.${google_dns_managed_zone.default.dns_name}"
  type = "CNAME"
  ttl  = 300

  managed_zone = google_dns_managed_zone.default.name

  rrdatas = [google_dns_managed_zone.default.dns_name]
}

resource "google_dns_record_set" "kubernetes" {
  name = "kubernetes.${google_dns_managed_zone.default.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.default.name

  rrdatas = ["8.8.8.8"] //google_compute_instance.frontend.network_interface[0].access_config[0].nat_ip
}

resource "google_dns_record_set" "default" {
  name = google_dns_managed_zone.default.dns_name
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.default.name

  rrdatas = [google_compute_global_address.default.address] //google_compute_instance.frontend.network_interface[0].access_config[0].nat_ip
}

# forwarding rule
resource "google_compute_global_forwarding_rule" "default" {
  name                  = "load-balancer-fowarding"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.default.id
  ip_address            = google_compute_global_address.default.id
}

# http proxy
resource "google_compute_target_http_proxy" "default" {
  name    = "load-balancer-http-proxy"
  url_map = google_compute_url_map.default.id
}

# url map
resource "google_compute_url_map" "default" {
  name            = "load-balancer-url-map"
  default_service = google_compute_backend_service.default.id
}

# backend service with custom request and response headers
resource "google_compute_backend_service" "default" {
  name                  = "load-balancer-backend-service"
  protocol              = "HTTP"
  port_name             = "customhttp"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 10
  health_checks         = [google_compute_health_check.http-health-check.id]
  backend {
    group           = google_compute_instance_group_manager.default.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_autoscaler" "default" {
  name   = "my-autoscaler"
  target = google_compute_instance_group_manager.default.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.9
    }
  }
}


resource "google_compute_instance_template" "default" {
  name         = "generic-week7"
  machine_type = "e2-small"

  tags = ["http-server", "https-server"]

  disk {
    source_image = "base-image"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral public IP
    }
  }
}

/*
resource "google_compute_target_pool" "default" {
  name = "my-target-pool"
}*/

resource "google_compute_http_health_check" "default" {
  name               = "default"
  request_path       = "/"
  check_interval_sec = 1
  timeout_sec        = 1
}

resource "google_compute_instance_group_manager" "default" {
  name = "my-igm"

  version {
    instance_template = google_compute_instance_template.default.id
    name              = "primary"
  }

  //target_pools       = [google_compute_target_pool.default.id]
  base_instance_name = google_compute_instance_template.default.name

  named_port {
    name = "customhttp"
    port = 80
  }

  named_port {
    name = "customhttps"
    port = 443
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.http-health-check.id
    initial_delay_sec = 300
  }
}

resource "google_compute_health_check" "http-health-check" {
  name = "http-health-check"

  timeout_sec        = 1
  check_interval_sec = 1

  http_health_check {
    port = 80
  }
}

resource "google_service_account" "default" {
  account_id   = "service-account-id"
  display_name = "Service Account Kubernetes"
}

resource "google_container_cluster" "primary" {
  name = "my-gke-cluster"

  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = "REGULAR"
  }
}

data "google_container_engine_versions" "default" {
  version_prefix = "1.24."
}

output "stable_channel_version" {
  value = data.google_container_engine_versions.default.release_channel_default_version["STABLE"]
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "my-node-pool"
  cluster    = google_container_cluster.primary.name
  node_count = 2
  version    = data.google_container_engine_versions.default.release_channel_default_version["STABLE"]

  node_config {
    preemptible  = true
    machine_type = "e2-small"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

