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
