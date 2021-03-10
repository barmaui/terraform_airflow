


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