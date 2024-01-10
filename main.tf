provider "google" {
  project = "testsabregcp"
}

# Create a bucket to store PDF files
resource "google_storage_bucket" "static" {
 name          = "chadam-sabre-gcp-bucket"
 location      = "US"
 storage_class = "STANDARD"

 uniform_bucket_level_access = true
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
  ]
}
