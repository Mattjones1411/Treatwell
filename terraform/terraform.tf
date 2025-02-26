provider "aws" {
  default_tags {
    tags = module.tags_provider.tags
  }
}
