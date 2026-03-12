output "cert-id" {
  description = "Certificate ID"
  value       = data.yandex_cm_certificate.validated.id
}
