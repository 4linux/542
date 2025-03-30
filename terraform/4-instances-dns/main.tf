provider "google" {
}

# ------------------------------------------------------------
# Instâncias
# ------------------------------------------------------------

resource "google_compute_address" "bastion_host_internal_ip" {
  name         = "bastion-host-internal-ip"
  region       = "us-east1"
  project      = "PROJECT_ID"
  address_type = "INTERNAL"
  subnetwork   = "bastion-subnet"
}

resource "google_compute_address" "ldap_server_internal_ip" {
  name         = "ldap-server-internal-ip"
  region       = "us-central1"
  project      = "ID_PROJECT_DEFAULT"
  address_type = "INTERNAL"
  subnetwork   = "infra-subnet"
}

resource "google_compute_address" "nfs_server_internal_ip" {
  name         = "nfs-server-internal-ip"
  region       = "us-central1"
  project      = "ID_PROJECT_DEFAULT"
  address_type = "INTERNAL"
  subnetwork   = "infra-subnet"
}

resource "google_compute_address" "bastion_host_static_ip" {
  name    = "bastion-host-static-ip"
  project = "PROJECT_ID"
  region  = "us-east1"
}

resource "google_compute_instance" "bastion_host" {
  name         = "bastion-host"
  machine_type = "e2-standard-2"
  project      = "PROJECT_ID"
  zone         = "us-east1-c"
  tags         = ["bastion-host"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = "50"
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "okd-network"
    subnetwork = "bastion-subnet"

    alias_ip_range {
      ip_cidr_range = google_compute_address.bastion_host_internal_ip.address
    }
    access_config {
      nat_ip = google_compute_address.bastion_host_static_ip.address
    }

  }

  metadata = {
    startup-script = <<-EOF
      #! /bin/bash

      # Clonar repositorio do curso
      git clone https://github.com/4linux/542.git
    EOF
  }
}

resource "google_compute_instance" "ldap_server" {
  name         = "ldap-server"
  machine_type = "e2-standard-2"
  zone         = "us-central1-c"
  project      = "ID_PROJECT_DEFAULT"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = "50"
      type  = "pd-balanced"
    }
  }
  network_interface {
    network = "projects/ID_PROJECT_DEFAULT/global/networks/infra-network"
    subnetwork = "projects/ID_PROJECT_DEFAULT/regions/us-central1/subnetworks/infra-subnet"

    alias_ip_range {
      ip_cidr_range = google_compute_address.ldap_server_internal_ip.address
    }
    access_config {}
  }

  metadata = {
    startup-script = <<-EOF
      #! /bin/bash

      # Atualiza a lista de pacotes
      apt-get update -y

      # Instala o OpenLDAP e pacotes associados
      DEBIAN_FRONTEND=noninteractive apt-get install -y slapd ldap-utils

      # Reconfigura o slapd para ser não interativo e define parâmetros básicos
      sudo debconf-set-selections <<< "slapd slapd/password1 password admin_password"
      sudo debconf-set-selections <<< "slapd slapd/password2 password admin_password"
      sudo debconf-set-selections <<< "slapd slapd/domain string example.com"
      sudo debconf-set-selections <<< "slapd shared/organization string Example Organization"

      # Reconfigura o slapd com as opções definidas acima
      DEBIAN_FRONTEND=noninteractive dpkg-reconfigure slapd

      # Modifica o slapd para escutar em todos os IPs
      sed -i 's/^SLAPD_SERVICES=.*/SLAPD_SERVICES="ldap:\/\/\/ ldapi:\/\/\/ ldaps:\/\/\/"/' /etc/default/slapd

      # Cria um arquivo LDIF para adicionar as OUs, o grupo e os usuários
      cat <<EOF_LDIF > /tmp/setup.ldif
      dn: ou=Users,dc=example,dc=com
      objectClass: organizationalUnit
      ou: Users

      dn: ou=Groups,dc=example,dc=com
      objectClass: organizationalUnit
      ou: Groups

      dn: cn=devops,ou=Groups,dc=example,dc=com
      objectClass: posixGroup
      cn: devops
      gidNumber: 5000
      memberUid: analista
      memberUid: developer

      dn: uid=analista,ou=Users,dc=example,dc=com
      objectClass: inetOrgPerson
      objectClass: posixAccount
      objectClass: top
      cn: analista
      sn: analista
      uid: analista
      uidNumber: 1001
      gidNumber: 5000
      homeDirectory: /home/analista
      loginShell: /bin/bash
      userPassword: $(slappasswd -s 4linux)

      dn: uid=developer,ou=Users,dc=example,dc=com
      objectClass: inetOrgPerson
      objectClass: posixAccount
      objectClass: top
      cn: developer
      sn: developer
      uid: developer
      uidNumber: 1002
      gidNumber: 5000
      homeDirectory: /home/developer
      loginShell: /bin/bash
      userPassword: $(slappasswd -s 4linux)
      EOF_LDIF

      # Aplica o arquivo LDIF para adicionar as OUs, o grupo e os usuários
      ldapadd -x -D cn=admin,dc=example,dc=com -w admin_password -f /tmp/setup.ldif

      # Reinicia o serviço para garantir que todas as configurações estejam aplicadas
      systemctl restart slapd

      # Ativa o slapd para iniciar no boot
      systemctl enable slapd

    EOF
  }
}

resource "google_compute_instance" "nfs_server" {
  name         = "nfs-server"
  machine_type = "e2-standard-2"
  zone         = "us-central1-c"
  project      = "ID_PROJECT_DEFAULT"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = "100"
      type  = "pd-ssd"
    }
  }
  network_interface {
    network = "projects/ID_PROJECT_DEFAULT/global/networks/infra-network"
    subnetwork = "projects/ID_PROJECT_DEFAULT/regions/us-central1/subnetworks/infra-subnet"

    alias_ip_range {
      ip_cidr_range = google_compute_address.nfs_server_internal_ip.address
    }
    access_config {}
  }

  metadata = {
    startup-script = <<-EOF
      #! /bin/bash

      # Atualiza a lista de pacotes e instala o pacote do NFS
      apt-get update
      apt-get install nfs-kernel-server -y


      # Cria a pasta nfs e altera as permissoes
      mkdir /nfs
      chown nobody:nogroup /nfs

      # Configura o compartilhamento do servidor NFS
      echo '/nfs *(rw,sync,no_subtree_check,no_root_squash)' >> /etc/exports

      # Aplicar as configurações do servidor NFS
      systemctl restart nfs-kernel-server

    EOF
  }
}

# ------------------------------------------------------------
# Criar automaticamente zona DNS pública com IP Bastion Host
# ------------------------------------------------------------

resource "google_dns_managed_zone" "okd4_zone" {
  name        = "okd4-zone"
  project     = "PROJECT_ID"
  dns_name    = "${replace(google_compute_address.bastion_host_static_ip.address, ".", "-")}.nip.io."
  description = "Zona DNS pública gerada automaticamente pelo Terraform."
  visibility  = "public"

  dnssec_config {
    state = "off"
  }
}
