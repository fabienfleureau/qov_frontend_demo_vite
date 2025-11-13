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

        # Detect libc implementation (glibc vs musl)
        LIBC_TYPE="glibc"
        if [ -f /etc/alpine-release ] || ldd --version 2>&1 | grep -q musl; then
          LIBC_TYPE="musl"
          echo "Detected musl libc (Alpine Linux)"

          # Install libstdc++ for musl Node.js binaries (required for C++ components)
          if command -v apk > /dev/null 2>&1; then
            echo "Installing libstdc++ for Node.js..."
            apk add --no-cache libstdc++ libgcc || {
              echo "ERROR: Failed to install libstdc++. Node.js requires C++ standard library."
              echo "SOLUTION: Pre-build your application:"
              echo "  npm install && npm run build"
              echo "  terraform apply -var='skip_build=true'"
              exit 1
            }
          fi
        else
          echo "Detected glibc-based system"
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

        # Build Node.js distribution name and URL
        NODE_VERSION="${var.node_version}.0.0"

        if [ "$LIBC_TYPE" = "musl" ] && [ "$NODE_OS" = "linux" ]; then
          # Use unofficial-builds.nodejs.org for musl binaries
          NODE_DIST="node-v$NODE_VERSION-$NODE_OS-$NODE_ARCH-musl"
          NODE_URL="https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/$NODE_DIST.tar.gz"
          echo "Using musl-compiled Node.js binary from unofficial-builds"
        else
          # Use official nodejs.org for glibc binaries
          NODE_DIST="node-v$NODE_VERSION-$NODE_OS-$NODE_ARCH"
          NODE_URL="https://nodejs.org/dist/v$NODE_VERSION/$NODE_DIST.tar.gz"
          echo "Using standard glibc Node.js binary from official nodejs.org"
        fi

        echo "Downloading Node.js from $NODE_URL..."
        $DOWNLOAD_CMD "$NODE_URL" $DOWNLOAD_OUTPUT /tmp/node.tar.gz

        echo "Extracting Node.js..."
        tar -xzf /tmp/node.tar.gz -C /tmp

        # Set absolute paths
        NODE_CMD="/tmp/$NODE_DIST/bin/node"
        NPM_CMD="/tmp/$NODE_DIST/bin/npm"

        # Verify installation
        if [ ! -f "$NODE_CMD" ]; then
          echo "ERROR: Node.js binary not found at $NODE_CMD"
          echo "Downloaded from: $NODE_URL"
          echo "Contents of /tmp:"
          ls -la /tmp/ | grep node || echo "No node directories found"
          exit 1
        fi

        echo "Node.js installed successfully: $($NODE_CMD --version)"
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
