/*
 * Module: aws-backend
 *
 * Bootstrap your terraform backend on AWS.
 *
 * This module configures resources for state locking for terraform >= 0.9.0
  */

data "aws_caller_identity" "current" {
}

resource "aws_dynamodb_table" "tf_backend_state_lock_table" {
  count            = var.dynamodb_lock_table_enabled ? 1 : 0
  name             = var.dynamodb_table_name
  read_capacity    = var.lock_table_read_capacity
  write_capacity   = var.lock_table_write_capacity
  hash_key         = "LockID"
  stream_enabled   = var.dynamodb_lock_table_stream_enabled
  stream_view_type = var.dynamodb_lock_table_stream_enabled ? var.dynamodb_lock_table_stream_view_type : ""

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(
    var.global_config,
    {
      Description        = "Terraform state locking table for account ${data.aws_caller_identity.current.account_id}.",
      ManagedByTerraform = "true"
    },
  )

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket" "tf_backend_bucket" {
  bucket        = var.s3_bucket_name
  acl           = "private"
  force_destroy = true

  tags = merge(
    var.global_config,
    {
      Description        = "Terraform S3 Backend bucket which stores the terraform state for account ${data.aws_caller_identity.current.account_id}."
      ManagedByTerraform = "true"
    },
  )

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = var.kms_key_id
        sse_algorithm     = var.kms_key_id == "" ? "AES256" : "aws:kms"
      }
    }
  }
  lifecycle {
    prevent_destroy = false
  }
}

data "aws_iam_policy_document" "tf_backend_bucket_policy" {
  statement {
    sid    = "RequireEncryptedTransport"
    effect = "Deny"
    actions = [
      "s3:*",
    ]
    resources = [
      "${aws_s3_bucket.tf_backend_bucket.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values = [
        false,
      ]
    }
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  statement {
    sid    = "RequireEncryptedStorage"
    effect = "Deny"
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${aws_s3_bucket.tf_backend_bucket.arn}/*",
    ]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values = [
        var.kms_key_id == "" ? "AES256" : "aws:kms",
      ]
    }
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "tf_backend_bucket_policy" {
  bucket = aws_s3_bucket.tf_backend_bucket.id
  policy = data.aws_iam_policy_document.tf_backend_bucket_policy.json
}