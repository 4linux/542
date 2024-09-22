provider "google" {
  region      = "us-central1"
}

resource "google_compute_network" "okd_network" {
  name                    = "okd-network"
  project                 = "ID_PROJECT_OKD4"
  auto_create_subnetworks = false
  mtu                     = 1460
  routing_mode            = "REGIONAL"
}

# Sub-rede master-subnet
resource "google_compute_subnetwork" "master_subnet" {
  name                     = "master-subnet"
  ip_cidr_range            = "10.0.0.0/24"
  region                   = "us-central1"
  network                  = google_compute_network.okd_network.id
  project                  = "ID_PROJECT_OKD4"
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}

# Sub-rede worker-subnet
resource "google_compute_subnetwork" "worker_subnet" {
  name                     = "worker-subnet"
  ip_cidr_range            = "10.0.1.0/24"
  region                   = "us-central1"
  network                  = google_compute_network.okd_network.id
  project                  = "ID_PROJECT_OKD4"
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}

# Roteador
resource "google_compute_router" "okd_router" {
  name     = "okd-router"
  network  = google_compute_network.okd_network.id
  region   = "us-central1"
  project  = "ID_PROJECT_OKD4"
}

# Cloud NAT para master-subnet
resource "google_compute_router_nat" "okd_nat_master" {
  name                               = "okd-nat-master"
  router                             = google_compute_router.okd_router.name
  region                             = "us-central1"
  project                            = "ID_PROJECT_OKD4"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  
  subnetwork {
    name                    = google_compute_subnetwork.master_subnet.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Cloud NAT para worker-subnet
resource "google_compute_router_nat" "okd_nat_worker" {
  name                               = "okd-nat-worker"
  router                             = google_compute_router.okd_router.name
  region                             = "us-central1"
  project                            = "ID_PROJECT_OKD4"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  
  subnetwork {
    name                    = google_compute_subnetwork.worker_subnet.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Firewall para permitir tráfego interno
resource "google_compute_firewall" "okd_network_allow_internal" {
  name    = "okd-network-allow-internal"
  network = google_compute_network.okd_network.self_link
  project = "ID_PROJECT_OKD4"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  direction     = "INGRESS"
  priority      = 65534
}

# Firewall para permitir SSH
resource "google_compute_firewall" "okd_network_allow_ssh" {
  name    = "okd-network-allow-ssh"
  network = google_compute_network.okd_network.self_link
  project = "ID_PROJECT_OKD4"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 65534
}

resource "google_compute_network" "infra_network" {
  name                    = "infra-network"
  project                 = "ID_PROJECT_DEFAULT"
  auto_create_subnetworks = false
  mtu                     = 1460
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "infra_subnet" {
  name                     = "infra-subnet"
  ip_cidr_range            = "10.0.2.0/24"
  region                   = "us-central1"
  network                  = google_compute_network.infra_network.id
  project                  = "ID_PROJECT_DEFAULT"
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}

resource "google_compute_route" "infra_route" {
  name              = "infra-route"
  network           = google_compute_network.infra_network.id
  dest_range        = "0.0.0.0/0"
  next_hop_gateway  = "default-internet-gateway"
  project           = "ID_PROJECT_DEFAULT"
  depends_on        = [google_compute_subnetwork.infra_subnet]
}

resource "google_compute_router" "infra_router" {
  name     = "infra-router"
  network  = google_compute_network.infra_network.id
  region   = "us-central1"
  project  = "ID_PROJECT_DEFAULT"
  depends_on = [google_compute_subnetwork.infra_subnet]
}

resource "google_compute_router_nat" "infra_nat" {
  name                               = "infra-nat"
  router                             = google_compute_router.infra_router.name
  region                             = "us-central1"
  project                            = "ID_PROJECT_DEFAULT"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  depends_on                         = [google_compute_router.infra_router]
}

resource "google_compute_firewall" "infra_network_allow_internal" {
  name    = "infra-network-allow-internal"
  network = google_compute_network.infra_network.self_link
  project = "ID_PROJECT_DEFAULT"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  direction     = "INGRESS"
  priority      = 65534
}

resource "google_compute_firewall" "infra_network_allow_ssh" {
  name    = "infra-network-allow-ssh"
  network = google_compute_network.infra_network.self_link
  project = "ID_PROJECT_DEFAULT"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 65534
}

resource "google_compute_firewall" "infra_network_allow_proxy" {
  name    = "infra-network-allow-proxy"
  network = google_compute_network.infra_network.self_link
  project = "ID_PROJECT_DEFAULT"

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 65534
}

resource "google_compute_network_peering" "infra_okd_peering" {
  name         = "infra-okd-peering"
  network      = google_compute_network.infra_network.id
  peer_network = google_compute_network.okd_network.id
  depends_on   = [google_compute_network.infra_network, google_compute_network.okd_network]
}

resource "google_compute_network_peering" "okd_infra_peering" {
  name         = "okd-infra-peering"
  network      = google_compute_network.okd_network.id
  peer_network = google_compute_network.infra_network.id
  depends_on   = [google_compute_network.infra_network, google_compute_network.okd_network]
}
