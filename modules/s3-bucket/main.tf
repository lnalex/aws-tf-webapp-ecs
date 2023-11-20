# Creates an encrypted S3 bucket with private ACL settings
resource "aws_s3_bucket" "bucket" {
  bucket_prefix = var.bucket_name
  lifecycle {
    prevent_destroy = true
  }
}

# Enable bucket SSE
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_sse_config" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

# Enable bucket versioning
resource "aws_s3_bucket_versioning" "bucket_versioning_config" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket settings to ensure public access is disabled
resource "aws_s3_bucket_ownership_controls" "bucket_ownership_config" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "bucket_acl_config" {
  depends_on = [aws_s3_bucket_ownership_controls.bucket_ownership_config]
  bucket     = aws_s3_bucket.bucket.id
  acl        = "private"
}

resource "aws_s3_bucket_public_access_block" "bucket_public_access_block_config" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
