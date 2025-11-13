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

# Make bucket public for website hosting
resource "aws_s3_bucket_public_access_block" "frontend_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket policy to allow public read access
resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend_public_access]
}

# Build and sync the frontend application
resource "null_resource" "build_and_sync" {
  # Trigger rebuild when source files change
  triggers = {
    always_run = timestamp()
  }

  # Install Node.js and npm if not available, then build the application
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash
      set -e

      # Function to install Node.js based on OS
      install_nodejs() {
        if command -v apt-get &> /dev/null; then
          # Debian/Ubuntu
          echo "Installing Node.js ${var.node_version} via apt..."
          curl -fsSL https://deb.nodesource.com/setup_${var.node_version}.x | bash -
          apt-get install -y nodejs
        elif command -v yum &> /dev/null; then
          # RHEL/CentOS/Amazon Linux
          echo "Installing Node.js ${var.node_version} via yum..."
          curl -fsSL https://rpm.nodesource.com/setup_${var.node_version}.x | bash -
          yum install -y nodejs
        elif command -v apk &> /dev/null; then
          # Alpine Linux
          echo "Installing Node.js via apk..."
          apk add --no-cache nodejs npm
        else
          echo "ERROR: Unsupported package manager. Please install Node.js manually."
          exit 1
        fi
      }

      # Check if npm is available
      if ! command -v npm &> /dev/null; then
        echo "npm not found. Installing Node.js..."
        install_nodejs
      else
        echo "npm found: $(npm --version)"
      fi

      # Build the application
      echo "Building application..."
      npm install
      npm run build
    EOT
    interpreter = ["bash", "-c"]
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

# Output the website URL
output "website_url" {
  value       = "http://${aws_s3_bucket.frontend_bucket.bucket}.s3-website-${var.aws_region}.amazonaws.com"
  description = "URL of the static website hosted on S3"
}

output "bucket_name" {
  value       = aws_s3_bucket.frontend_bucket.bucket
  description = "Name of the S3 bucket"
}
