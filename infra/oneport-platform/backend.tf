terraform {
  backend "s3" {
    key = "dev/oneport-platform/terraform.tfstate"
  }
}
