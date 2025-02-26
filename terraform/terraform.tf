terraform {
  required_providers {
    aws = {
      version = "~> 5.52.0"
    }
  }

  required_version = "1.9.4"
}

provider "aws" {
  default_tags {
    tags = module.tags_provider.tags
  }
}
