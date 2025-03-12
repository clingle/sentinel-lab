variable "encryption_key_passphrase" {
  description = "Passphrase for statefile encryption. Must be minimum of 16 characters."
  type        = string

  validation {
    condition     = length(var.encryption_key_passphrase) >= 16
    error_message = "Passphrase must be at least 16 characters."
  }
}
