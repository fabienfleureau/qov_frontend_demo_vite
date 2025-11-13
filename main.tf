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
        echo "npm not found. Downloading portable Node.js..."

        # Check if we're on Alpine Linux (musl libc) - Node.js binaries need glibc
        if [ -f /etc/alpine-release ]; then
          echo "Detected Alpine Linux. Installing glibc compatibility..."
          # Install glibc compatibility layer for Alpine
          if ! command -v apk > /dev/null 2>&1; then
            echo "ERROR: Alpine detected but apk not found. Cannot install glibc."
            echo "Please pre-build your application or use a glibc-based image."
            exit 1
          fi

          apk add --no-cache libstdc++ || echo "Warning: Could not install libstdc++"

          # Check if glibc is available, if not, warn user
          if ! [ -f /lib/ld-linux-x86-64.so.2 ] && ! [ -f /lib64/ld-linux-x86-64.so.2 ]; then
            echo "WARNING: glibc not available. Node.js requires glibc."
            echo "Installing gcompat for compatibility..."
            apk add --no-cache gcompat || {
              echo "ERROR: Cannot install gcompat. Node.js binaries won't work on musl."
              echo "SOLUTION: Pre-build your application before running Terraform:"
              echo "  npm install && npm run build"
              echo "  terraform apply -var='skip_build=true'"
              exit 1
            }
          fi
        fi

        # Check for download tool
        if command -v curl > /dev/null 2>&1; then
          DOWNLOAD_CMD="curl -fsSL"
          DOWNLOAD_OUTPUT="-o"
        elif command -v wget > /dev/null 2>&1; then
          DOWNLOAD_CMD="wget -q"
          DOWNLOAD_OUTPUT="-O"
        else
          echo "ERROR: Neither curl nor wget found. Cannot download Node.js."
          echo "Please install curl or wget, or pre-install Node.js in your pipeline."
          exit 1
        fi

        # Detect architecture
        ARCH=$(uname -m)
        case $ARCH in
          x86_64) NODE_ARCH="x64" ;;
          aarch64|arm64) NODE_ARCH="arm64" ;;
          armv7l) NODE_ARCH="armv7l" ;;
          *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
        esac

        # Detect OS
        OS=$(uname -s)
        case $OS in
          Linux) NODE_OS="linux" ;;
          Darwin) NODE_OS="darwin" ;;
          *) echo "Unsupported OS: $OS"; exit 1 ;;
        esac

        # Download and extract portable Node.js
        NODE_VERSION="${var.node_version}.0.0"
        NODE_DIST="node-v$NODE_VERSION-$NODE_OS-$NODE_ARCH"
        NODE_URL="https://nodejs.org/dist/v$NODE_VERSION/$NODE_DIST.tar.gz"

        echo "Downloading Node.js from $NODE_URL..."
        $DOWNLOAD_CMD "$NODE_URL" $DOWNLOAD_OUTPUT /tmp/node.tar.gz

        echo "Extracting Node.js..."
        tar -xzf /tmp/node.tar.gz -C /tmp

        # Debug: Check what was extracted
        echo "Checking extracted files in /tmp..."
        ls -la /tmp/ | grep node || echo "No node directories found"

        # Set absolute paths
        NODE_CMD="/tmp/$NODE_DIST/bin/node"
        NPM_CMD="/tmp/$NODE_DIST/bin/npm"

        echo "Expected Node.js location: /tmp/$NODE_DIST"
        if [ -d "/tmp/$NODE_DIST" ]; then
          echo "Directory exists, checking binaries..."
          ls -la "/tmp/$NODE_DIST/bin/" || echo "bin directory not found"

          if [ -f "$NODE_CMD" ]; then
            echo "node binary found, checking if executable..."
            file "$NODE_CMD" || echo "Cannot determine file type"
            ldd "$NODE_CMD" 2>&1 || echo "Cannot check dependencies (static binary or ldd not available)"
          else
            echo "ERROR: node binary not found at $NODE_CMD"
            exit 1
          fi
        else
          echo "ERROR: Expected directory /tmp/$NODE_DIST does not exist"
          exit 1
        fi

        echo "Portable Node.js ready: $($NODE_CMD --version)"
        echo "npm version: $($NPM_CMD --version)"
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

# Output the website URL
output "website_url" {
  value       = "http://${aws_s3_bucket.frontend_bucket.bucket}.s3-website-${var.aws_region}.amazonaws.com"
  description = "URL of the static website hosted on S3"
}

output "bucket_name" {
  value       = aws_s3_bucket.frontend_bucket.bucket
  description = "Name of the S3 bucket"
}
