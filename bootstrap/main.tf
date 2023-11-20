terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.26.0"
    }
  }

  required_version = "~> 1.6.4"
}

# Should reflect config defined in provider.tf
variable "bucket_name" {
  description = "S3 bucket name for remote state"
}

variable "region" {
  description = "AWS region"
}

variable "table_name" {
  description = "DDB table for locking"
}

provider "aws" {
  region = var.region
}

resource "aws_kms_key" "bucket_sse_key" {
  description             = "This key is used to encrypt S3 bucket objects"
  deletion_window_in_days = 10
}

# Remote backend bucket
resource "aws_s3_bucket" "remote_bucket" {
  bucket = var.bucket_name
}

# Enable bucket SSE
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_sse_config" {
  bucket = aws_s3_bucket.remote_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.bucket_sse_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Enable bucket versioning
resource "aws_s3_bucket_versioning" "bucket_versioning_config" {
  bucket = aws_s3_bucket.remote_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket settings to ensure public access is disabled
resource "aws_s3_bucket_ownership_controls" "bucket_ownership_config" {
  bucket = aws_s3_bucket.remote_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "bucket_acl_config" {
  depends_on = [aws_s3_bucket_ownership_controls.bucket_ownership_config]
  bucket = aws_s3_bucket.remote_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "bucket_public_access_block_config" {
  bucket = aws_s3_bucket.remote_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lock table
resource "aws_dynamodb_table" "lock_table" {
    name = var.table_name
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "LockID"
    attribute {
      name = "LockID"
      type = "S"
    }
}