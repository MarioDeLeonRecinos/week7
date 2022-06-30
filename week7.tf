
resource "google_project_service" "services" {
  for_each = toset(var.services)
  service  = each.value
}

resource "google_dns_managed_zone" "default" {
  name        = "week7"
  dns_name    = "week7challenge.tk."
  description = "Week 7 DNS"

}

resource "google_dns_record_set" "frontend" {
  name = "www.${google_dns_managed_zone.default.dns_name}"
  type = "CNAME"
  ttl  = 300

  managed_zone = google_dns_managed_zone.default.name

  rrdatas = ["week7challenge.tk."]
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

  rrdatas = ["8.8.8.8"] //google_compute_instance.frontend.network_interface[0].access_config[0].nat_ip
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

  tags = ["http-server","https-server", "web"]

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

resource "google_compute_firewall" "default" {
  name    = "test-firewall"
  network = "default"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["80", "8080", "443", "22", "3389"]
  }
  source_ranges = ["0.0.0.0"]
}


