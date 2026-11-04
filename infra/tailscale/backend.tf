terraform {
  backend "s3" {
    key = "dev/tailscale/terraform.tfstate"
  }
}
