provider "google" {
  project = "PROJECT_ID"
}

# ----------------------------------------------------------------------
# Definir permissões para a conta Compute Engine default service account 
# ----------------------------------------------------------------------

resource "google_project_iam_member" "default_service_account_roles" {
  for_each = toset([
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountKeyAdmin",
    "roles/storage.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/compute.loadBalancerAdmin",
    "roles/compute.admin",
    "roles/compute.storageAdmin",
    "roles/dns.admin",
    "roles/editor",
    "roles/iam.securityAdmin",
    "roles/iam.serviceAccountUser"
  ])

  project = "PROJECT_ID"
  role    = each.key
  member  = "serviceAccount:SERVICE_ACCOUNT_ID"
}

# ------------------------------------------------------------
# Criar e salvar chave JSON da conta padrão
# ------------------------------------------------------------

resource "google_service_account_key" "compute_default_sa_key" {
  service_account_id = "SERVICE_ACCOUNT_ID"
}

resource "local_file" "compute_sa_key_json" {
  content  = base64decode(google_service_account_key.compute_default_sa_key.private_key)
  filename = "./chave.json"
}

# ------------------------------------------------------------
# Infraestrutura de rede (VPC, subnets, NAT, firewall)
# ------------------------------------------------------------

resource "google_compute_network" "okd_network" {
  name                    = "okd-network"
  auto_create_subnetworks = false
  mtu                     = 1460
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "master_subnet" {
  name                     = "master-subnet"
  ip_cidr_range            = "10.0.0.0/24"
  region                   = "us-central1"
  network                  = google_compute_network.okd_network.id
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}

resource "google_compute_subnetwork" "worker_subnet" {
  name                     = "worker-subnet"
  ip_cidr_range            = "10.0.1.0/24"
  region                   = "us-central1"
  network                  = google_compute_network.okd_network.id
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}

resource "google_compute_subnetwork" "bastion_subnet" {
  name                     = "bastion-subnet"
  ip_cidr_range            = "10.0.2.0/24"
  region                   = "us-east1"
  network                  = google_compute_network.okd_network.id
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}

resource "google_compute_router" "okd_router" {
  name    = "okd-router"
  network = google_compute_network.okd_network.id
  region  = "us-central1"
}

resource "google_compute_router" "bastion_router" {
  name    = "bastion-router"
  network = google_compute_network.okd_network.id
  region  = "us-east1"
}

resource "google_compute_router_nat" "okd_nat" {
  name                               = "okd-nat"
  router                             = google_compute_router.okd_router.name
  region                             = google_compute_router.okd_router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.master_subnet.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  subnetwork {
    name                    = google_compute_subnetwork.worker_subnet.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_router_nat" "bastion_nat" {
  name                               = "bastion-nat"
  router                             = google_compute_router.bastion_router.name
  region                             = google_compute_router.bastion_router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.bastion_subnet.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_firewall" "okd_network_allow_internal" {
  name    = "okd-network-allow-internal"
  network = google_compute_network.okd_network.id

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

resource "google_compute_firewall" "okd_network_allow_ssh" {
  name    = "okd-network-allow-ssh"
  network = google_compute_network.okd_network.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  direction     = "INGRESS"
  priority      = 65534
}

resource "google_compute_firewall" "allow_bastion_host" {
  name    = "allow-bastion-host"
  network = google_compute_network.okd_network.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "6443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["bastion-host"]
}

# ------------------------------------------------------------
# Instância Bastion Host
# ------------------------------------------------------------

resource "google_compute_address" "bastion_host_internal_ip" {
  name         = "bastion-host-internal-ip"
  region       = "us-east1"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.bastion_subnet.id
}

resource "google_compute_address" "bastion_host_static_ip" {
  name   = "bastion-host-static-ip"
  region = "us-east1"
}

resource "google_compute_instance" "bastion_host" {
  name         = "bastion-host"
  machine_type = "e2-standard-2"
  zone         = "us-east1-c"
  tags         = ["bastion-host"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = google_compute_network.okd_network.id
    subnetwork = google_compute_subnetwork.bastion_subnet.id
    network_ip = google_compute_address.bastion_host_internal_ip.address

    access_config {
      nat_ip = google_compute_address.bastion_host_static_ip.address
    }
  }

  metadata = {
    startup-script = <<-EOF
      #!/bin/bash
      git clone https://github.com/4linux/542.git
    EOF
  }
}

# ------------------------------------------------------------
# Criar automaticamente zona DNS pública com IP Bastion Host
# ------------------------------------------------------------

resource "google_dns_managed_zone" "okd4_zone" {
  name        = "okd4-zone"
  dns_name    = "${google_compute_address.bastion_host_static_ip.address}.nip.io."
  description = "Zona DNS pública gerada automaticamente pelo Terraform."
  visibility  = "public"

  dnssec_config {
    state = "off"
  }
}

