provider "google" {
  project = "PROJECT_ID"
}

# ---------------------------------------
# Ativando APIs necessarias para o OKD 4
# ---------------------------------------

resource "google_project_service" "enabled_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "cloudapis.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "dns.googleapis.com",
    "iamcredentials.googleapis.com",
    "iam.googleapis.com",
    "servicemanagement.googleapis.com",
    "serviceusage.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "deploymentmanager.googleapis.com",
    "backupdr.googleapis.com",
    "networksecurity.googleapis.com",
    "firebase.googleapis.com",
    "certificatemanager.googleapis.com"
  ])

  project            = "PROJECT_ID"
  service            = each.key
  disable_on_destroy = false
}
