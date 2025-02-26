variable "backend_bucket" {
    type = string
    description = "The bucket to keep the TF state file in"
}

variable "aws_region" {
    type = string
    description = "The aws region" 
}

variable "aws_account_id" {
  type = string
  description = "aws account id"
}
