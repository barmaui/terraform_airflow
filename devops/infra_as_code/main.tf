provider "google" {
  project = var.project_name
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_name
  region  = var.region
  zone    = var.zone
}

//data "google_service_account" "nissan_sa" {
//  account_id = var.service_account
//}

resource "google_service_account" "airflow-sa" {
  account_id   = "airflow-sa"
  display_name = "Service Account"
}

resource "google_compute_subnetwork" "subnet" {
  name          = "airflow-subnetwork"
  ip_cidr_range = "10.0.0.0/8"
  region        = var.region
  network       = google_compute_network.airflow-network.id
}

resource "google_compute_network" "airflow-network" {
  name                    = "airflow-network"
  auto_create_subnetworks = false
}

resource "google_compute_instance" "airflow-vm" {
  name         = "airflow-vm"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-minimal-2004-focal-v20210223a"
      size = "10"
    }
  }

  network_interface {
    network = google_compute_network.airflow-network.name
    subnetwork = google_compute_subnetwork.subnet.name

    access_config {
      network_tier = "STANDARD"
    }
  }

  metadata_startup_script = "${file(var.start_up_script)}"

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.airflow-sa.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_firewall" "ssh-access" {
  name    = "allow-ssh-access"
  network = google_compute_network.airflow-network.name
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

}

resource "google_compute_firewall" "airflow-network-allow-http" {
  name    = "airflow-network-allow-http"
  network = google_compute_network.airflow-network.name
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["80", "8080"]
  }

}

resource "google_compute_firewall" "loadbalancer-access" {
  name    = "loadbalancer-access"
  network = google_compute_network.airflow-network.name
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

}

resource "google_compute_instance_group" "airflow-instance-group" {
  name        = "airflow-instance-group"
  description = "Airflow instance group"

  instances = [
    google_compute_instance.airflow-vm.id
  ]

  named_port {
    name = "http8080"
    port = "8080"
  }

  zone = var.zone
}

resource "google_compute_global_address" "private_ip_address" {
  provider = google-beta

  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.airflow-network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider = google-beta

  network                 = google_compute_network.airflow-network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database" "database" {
  name     = "airflow"
  instance = google_sql_database_instance.airflow-db.name
}

resource "google_sql_database_instance" "airflow-db" {
  provider = google-beta

  name   = "airflow-db"
  database_version = "POSTGRES_11"
  region = var.region

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.airflow-network.id
    }
  }
}

resource "google_compute_address" "airflow-static-ip" {
  name         = "airflow-static-ip"
  address_type = "EXTERNAL"
  region       = var.region
  network_tier = "STANDARD"
}

resource "google_dns_record_set" "a" {
  name         = "backend.${google_dns_managed_zone.airflow.dns_name}"
  managed_zone = google_dns_managed_zone.airflow.name
  type         = "A"
  ttl          = 300

  rrdatas = [google_compute_address.airflow-static-ip.address]
}

resource "google_dns_managed_zone" "airflow" {
  name     = "airflow"
  dns_name = "airflow-training-de.com."
}