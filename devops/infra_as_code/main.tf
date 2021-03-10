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

data "google_service_account" "nissan_sa" {
  account_id = var.service_account
}

resource "google_service_account" "airflow-sa" {
  account_id   = "airflow-sa"
  display_name = "Service Account"
}

module network_config {
  source = "./network_config"
  region = var.region
}

module postgres {
  source = "./postgres"
  region = var.region
  network = module.network_config.airflow-network.id
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
    network = module.network_config.airflow-network.name
    subnetwork = module.network_config.airflow-subnet.name

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