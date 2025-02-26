terraform {
  backend "s3" {
    bucket         = "terraform"
    key            = "country-extraction/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform"
    encrypt        = true
  }
}
