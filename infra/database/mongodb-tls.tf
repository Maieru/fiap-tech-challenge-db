locals {
  mongodb_host = "mongodb-0.mongodb.fiap-mongodb.svc.cluster.local"
}

resource "random_password" "mongodb_keyfile" {
  length  = 96
  special = false
}

resource "tls_private_key" "mongodb_ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "tls_self_signed_cert" "mongodb_ca" {
  private_key_pem       = tls_private_key.mongodb_ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 43800
  allowed_uses          = ["cert_signing", "crl_signing", "digital_signature"]
  subject { common_name = "FIAP MongoDB Lab CA" }
}
resource "tls_private_key" "mongodb_server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "tls_cert_request" "mongodb_server" {
  private_key_pem = tls_private_key.mongodb_server.private_key_pem
  dns_names       = [local.mongodb_host, "mongodb.fiap-mongodb.svc.cluster.local", "localhost"]
  ip_addresses    = ["127.0.0.1"]
  subject { common_name = local.mongodb_host }
}
resource "tls_locally_signed_cert" "mongodb_server" {
  cert_request_pem      = tls_cert_request.mongodb_server.cert_request_pem
  ca_private_key_pem    = tls_private_key.mongodb_ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.mongodb_ca.cert_pem
  validity_period_hours = 8760
  early_renewal_hours   = 168
  allowed_uses          = ["server_auth", "client_auth", "digital_signature", "key_encipherment"]
}
