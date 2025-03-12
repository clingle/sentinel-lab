terraform {
  encryption {
    key_provider "pbkdf2" "encryption_key" {
      passphrase = var.encryption_key_passphrase
    }

    method "aes_gcm" "encrypt" {
      keys = key_provider.pbkdf2.encryption_key
    }

    state {
      method = method.aes_gcm.encrypt
    }
  }

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.1.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.22.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "0.13.0"
    }
  }
}
