output "acm_certificate" {
  value = aws_acm_certificate.cert
  depends_on = [ aws_acm_certificate_validation.cert_validation ]
}