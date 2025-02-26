terraform {
  backend "s3" {
    bucket         = var.backend_bucket
    key            = "country-extraction/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.backend_bucket
    encrypt        = true
  }
}
