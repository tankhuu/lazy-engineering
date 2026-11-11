terraform {
  required_version = ">= 1.9.0"

  # Local state on purpose: this root creates the remote backend used by the Terragrunt units in infra/deployment.
  # Keep terraform.tfstate out of git (see .gitignore) and store it in a vault after the first run.

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.13"
    }
  }
}
