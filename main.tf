variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_suffix" {
  description = "Unique suffix for bucket name"
  type        = string
  default     = "static-site-demo-vite"
}

variable "node_version" {
  description = "Node.js version to install if npm is not available"
  type        = string
  default     = "20"
}

variable "skip_build" {
  description = "Skip the build step (use when you pre-build the application)"
  type        = bool
  default     = false
}

provider "aws" {
  region = var.aws_region
}

# S3 bucket for static website hosting
resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = "qovery-${var.bucket_suffix}"
  force_destroy = true
}

# Enable static website hosting
resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "frontend_oai" {
  comment = "OAI for ${aws_s3_bucket.frontend_bucket.bucket}"
}

# Bucket policy to allow CloudFront access
resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "CloudFrontReadGetObject"
        Effect    = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.frontend_oai.iam_arn
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "frontend_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.frontend_bucket.bucket}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.frontend_oai.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend_bucket.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # Custom error response for SPA routing
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Build and sync the frontend application
resource "null_resource" "build_and_sync" {
  count = var.skip_build ? 0 : 1

  # Trigger rebuild when source files change
  triggers = {
    always_run = timestamp()
  }

  # Download portable Node.js and build the application (no installation or admin rights needed)
  provisioner "local-exec" {
    command = <<-EOT
      set -e

      # Check if npm is available
      if command -v npm > /dev/null 2>&1; then
        echo "npm found: $(npm --version)"
        NPM_CMD="$(command -v npm)"
      else
        echo "npm not found: exiting"
        exit
      fi

      # Build the application
      echo "Building application..."
      $NPM_CMD install
      $NPM_CMD run build
    EOT
    interpreter = ["sh", "-c"]
  }

  # Sync built files to S3
  provisioner "local-exec" {
    command = "aws s3 sync ./dist s3://${aws_s3_bucket.frontend_bucket.id}/ --delete"
  }

  depends_on = [
    aws_s3_bucket.frontend_bucket,
    aws_s3_bucket_website_configuration.frontend_website
  ]
}

# Sync pre-built files to S3 (when skip_build is true)
resource "null_resource" "sync_prebuild" {
  count = var.skip_build ? 1 : 0

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "aws s3 sync ./dist s3://${aws_s3_bucket.frontend_bucket.id}/ --delete"
  }

  depends_on = [
    aws_s3_bucket.frontend_bucket,
    aws_s3_bucket_website_configuration.frontend_website
  ]
}

# Output the CloudFront URL (primary)
output "cloudfront_url" {
  value       = "https://${aws_cloudfront_distribution.frontend_distribution.domain_name}"
  description = "CloudFront distribution URL (HTTPS enabled)"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.frontend_distribution.domain_name
  description = "CloudFront distribution domain name"
}

# Output the website URL (S3 direct access - for reference)
output "website_url" {
  value       = "http://${aws_s3_bucket.frontend_bucket.bucket}.s3-website-${var.aws_region}.amazonaws.com"
  description = "URL of the static website hosted on S3 (direct access, not recommended)"
}

output "bucket_name" {
  value       = aws_s3_bucket.frontend_bucket.bucket
  description = "Name of the S3 bucket"
}
