provider "google" {
  project = "testsabregcp"
}


# Create a bucket to store PDF files
resource "google_storage_bucket" "static" {
 name          = "chadam-sabre-gcp-bucket"
 location      = "US"
 storage_class = "STANDARD"
 force_destroy = "true" 
 uniform_bucket_level_access = false 
}


# Make bucket public
resource "google_storage_bucket_iam_member" "member" {
  provider = google
  bucket   = google_storage_bucket.static.name
  role     = "roles/storage.objectViewer"
  member   = "allUsers"
}


# Create a SQL database instance
resource "google_sql_database_instance" "default" {
  name             = "chadam-db-sql-mysql"
  region           = "us-central1"
  database_version = "MYSQL_5_7"
  deletion_protection = "false"

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      # The network name of the cloudsql instance
      ipv4_enabled    = true
    }
  }
}

# Create a SQL database within the newly created SQL database instance
resource "google_sql_database" "default" {
  name       = "sabre"
  instance   = google_sql_database_instance.default.name
  project    = google_sql_database_instance.default.project
}

# Create user for the newly created SQL database instance
resource "google_sql_user" "users" {
  name     = "root"
  instance = google_sql_database_instance.default.name
  password = "password"
}

# Create bucket to store cloud function code 
resource "google_storage_bucket" "cloud-function-bucket" {
 name          = "chadam-sabre-cloudcuntion-bucket"
 location      = "US"
 storage_class = "STANDARD"
 uniform_bucket_level_access = true
}

# Generates an archive of the source code compressed as a .zip file.
data "archive_file" "source" {
  type        = "zip"
  source_dir  = "cf/"
  output_path = "${path.module}/function.zip"
}


# Add zip source code to the cloud function bucket
resource "google_storage_bucket_object" "zip" {
  source       = data.archive_file.source.output_path
  content_type = "application/zip"
  name         = "src-${data.archive_file.source.output_md5}.zip"
  bucket       = google_storage_bucket.cloud-function-bucket.name
  depends_on = [
    google_storage_bucket.cloud-function-bucket,
    data.archive_file.source
  ]
}

resource "google_project_service" "cloud_build_api" {
  service = "cloudbuild.googleapis.com"
}


resource "google_project_service" "gcp_resource_manager_api" {
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "cloud_function_api" {
  service = "cloudfunctions.googleapis.com"
  depends_on = [
    google_project_service.gcp_resource_manager_api

  ]
}


# Create cloud function
resource "google_cloudfunctions_function" "Cloud_function" {
  name                  = "sabre-gcp-cloud-function"
  runtime               = "python39"
  source_archive_bucket = google_storage_bucket.cloud-function-bucket.name
  source_archive_object = google_storage_bucket_object.zip.name
  entry_point           = "writeToSql"
  region           = "us-central1"
trigger_http = "true"
  depends_on = [
    google_storage_bucket.cloud-function-bucket,
    google_storage_bucket_object.zip,
    google_project_service.cloud_function_api,
    google_project_service.gcp_resource_manager_api,
    google_project_service.cloud_build_api
  ]
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.Cloud_function.project
  region         = google_cloudfunctions_function.Cloud_function.region
  cloud_function = google_cloudfunctions_function.Cloud_function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}
