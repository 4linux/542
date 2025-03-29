provider "google" {
  region = "us-central1"
}

# ------------------------------------------------------------
# Firewall para liberar as portas LDAP (389) e NFS (2049)
# ------------------------------------------------------------

resource "google_compute_firewall" "allow_ldap" {
  name    = "allow-ldap"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["389"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ldap-server"]
  direction     = "INGRESS"
  priority      = 1000
}

resource "google_compute_firewall" "allow_nfs" {
  name    = "allow-nfs"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["2049"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["nfs-server"]
  direction     = "INGRESS"
  priority      = 1000
}

# ------------------------------------------------------------
# Endereços IP internos fixos para servidores LDAP e NFS
# ------------------------------------------------------------

resource "google_compute_address" "ldap_server_internal_ip" {
  name         = "ldap-server-internal-ip"
  region       = "us-central1"
  address_type = "INTERNAL"
}

resource "google_compute_address" "nfs_server_internal_ip" {
  name         = "nfs-server-internal-ip"
  region       = "us-central1"
  address_type = "INTERNAL"
}

# ------------------------------------------------------------
# Instância LDAP Server
# ------------------------------------------------------------

resource "google_compute_instance" "ldap_server" {
  name         = "ldap-server"
  machine_type = "e2-standard-2"
  zone         = "us-central1-c"
  tags         = ["ldap-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = "50"
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = "default"
    subnetwork = "default"

    alias_ip_range {
      ip_cidr_range = google_compute_address.ldap_server_internal_ip.address
    }

    access_config {}
  }

  metadata = {
    startup-script = <<-EOF
      #! /bin/bash
      apt-get update -y
      DEBIAN_FRONTEND=noninteractive apt-get install -y slapd ldap-utils

      sudo debconf-set-selections <<< "slapd slapd/password1 password admin_password"
      sudo debconf-set-selections <<< "slapd slapd/password2 password admin_password"
      sudo debconf-set-selections <<< "slapd slapd/domain string example.com"
      sudo debconf-set-selections <<< "slapd shared/organization string Example Organization"
      DEBIAN_FRONTEND=noninteractive dpkg-reconfigure slapd

      sed -i 's/^SLAPD_SERVICES=.*/SLAPD_SERVICES="ldap:\/\/\/ ldapi:\/\/\/ ldaps:\/\/\/"/' /etc/default/slapd

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

      ldapadd -x -D cn=admin,dc=example,dc=com -w admin_password -f /tmp/setup.ldif
      systemctl restart slapd
      systemctl enable slapd
    EOF
  }
}

# ------------------------------------------------------------
# Instância NFS Server
# ------------------------------------------------------------

resource "google_compute_instance" "nfs_server" {
  name         = "nfs-server"
  machine_type = "e2-standard-2"
  zone         = "us-central1-c"
  tags         = ["nfs-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = "100"
      type  = "pd-ssd"
    }
  }

  network_interface {
    network    = "default"
    subnetwork = "default"

    alias_ip_range {
      ip_cidr_range = google_compute_address.nfs_server_internal_ip.address
    }

    access_config {}
  }

  metadata = {
    startup-script = <<-EOF
      #! /bin/bash
      apt-get update
      apt-get install nfs-kernel-server -y
      mkdir /nfs
      chown nobody:nogroup /nfs
      echo '/nfs *(rw,sync,no_subtree_check,no_root_squash)' >> /etc/exports
      systemctl restart nfs-kernel-server
    EOF
  }
}
