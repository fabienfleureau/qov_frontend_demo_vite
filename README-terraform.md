# Terraform S3 Static Website Deployment

This Terraform configuration deploys a Vite application to AWS S3 with static website hosting.

## Prerequisites

- AWS CLI installed
- AWS credentials configured
- Terraform installed
- **Optional:** Node.js and npm (will be auto-installed if missing)

## How It Works

The Terraform configuration supports two approaches:

### Approach 1: Pre-build (Recommended for Alpine/musl-based containers)

Build your application before running Terraform:

```bash
npm install && npm run build
terraform apply -var="skip_build=true"
```

### Approach 2: Auto-download Node.js (Works on glibc-based systems)

For glibc-based containers (Debian, Ubuntu, etc.), Terraform can automatically:

1. **Check for npm** - Uses existing npm if available
2. **Download portable Node.js** - If npm is missing:
   - Downloads official Node.js binaries from nodejs.org
   - Installs glibc compatibility on Alpine (if possible)
   - Extracts to `/tmp`
3. **Build the app** - Runs `npm install && npm run build`
4. **Sync to S3** - Uploads built files

**Note:** Node.js official binaries require glibc. On Alpine Linux (musl libc), the script attempts to install gcompat, but pre-building is more reliable.

## Usage

### Recommended: Pre-build approach

```bash
# Build the application first
npm install
npm run build

# Deploy with Terraform (skips build)
terraform init
terraform apply -var="skip_build=true"
```

### Alternative: Auto-build (may require glibc)

```bash
# Terraform will download Node.js and build automatically
terraform init
terraform apply
```

## Variables

- `aws_region`: AWS region (default: "us-east-1")
- `bucket_suffix`: Unique suffix for bucket name (default: "static-site-demo-vite")
- `node_version`: Node.js major version to download if npm is missing (default: "20")
- `skip_build`: Skip the build step, use pre-built dist folder (default: false)

## Outputs

- `website_url`: The HTTP URL of your hosted website
- `bucket_name`: The S3 bucket name

## Pipeline Examples

### GitHub Actions (Recommended approach)

```yaml
name: Deploy to S3

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'

      - name: Build application
        run: |
          npm install
          npm run build

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2

      - name: Deploy with Terraform
        run: |
          terraform init
          terraform apply -var="skip_build=true" -auto-approve
```

### GitLab CI (with pre-build)

```yaml
stages:
  - build
  - deploy

build:
  image: node:20-alpine
  stage: build
  script:
    - npm install
    - npm run build
  artifacts:
    paths:
      - dist/

deploy:
  image: hashicorp/terraform:latest
  stage: deploy
  script:
    - terraform init
    - terraform apply -var="skip_build=true" -auto-approve
  only:
    - main
```

### Qovery / Generic Pipeline

```bash
# Pre-build approach (recommended)
npm install && npm run build
terraform init
terraform apply -var="skip_build=true" -auto-approve
```

## Troubleshooting

### Build fails with "npm: not found"

This shouldn't happen as npm is automatically downloaded. Check:
- Internet connectivity (needs access to nodejs.org)
- `/tmp` directory is writable
- Architecture is supported (x64, arm64, armv7l on Linux/macOS)
- Either `curl` or `wget` is available (script supports both)

### "Neither curl nor wget found" error

The Terraform container needs either curl or wget to download Node.js. Solutions:
- Install curl in your pipeline: `apk add curl` (Alpine) or `apt-get install -y curl` (Debian)
- Or use a Terraform image that includes curl (most do)
- Or pre-install Node.js before running Terraform

### Architecture not supported

If you see "Unsupported architecture" error, you may need to:
- Pre-install Node.js in your pipeline
- Or pre-build the application and sync manually

### Want to use a specific Node.js version?

```bash
terraform apply -var="node_version=18"  # Use Node.js 18.x
terraform apply -var="node_version=22"  # Use Node.js 22.x
```

## Clean Up

```bash
terraform destroy
```
