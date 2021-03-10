output airflow-network {
    value = google_compute_network.airflow-network
}

output airflow-subnet{
    value = google_compute_subnetwork.subnet
}