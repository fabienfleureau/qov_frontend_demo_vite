# Terraform S3 Static Website Deployment

This Terraform configuration deploys a Vite application to AWS S3 with static website hosting.

## Prerequisites

- AWS CLI installed
- AWS credentials configured
- Terraform installed
- **Optional:** Node.js and npm (will be auto-installed if missing)

## How It Works

The Terraform configuration automatically handles npm using **portable Node.js binaries**:

1. **Checks for npm** - If npm is already installed, it uses it
2. **Downloads portable Node.js** - If npm is missing, it automatically downloads the official Node.js portable binaries:
   - No installation required
   - No admin/sudo rights needed
   - Supports Linux (x64, arm64, armv7l) and macOS
   - Downloads from official nodejs.org
   - Extracts to `/tmp` and adds to PATH
3. **Builds the app** - Runs `npm install && npm run build`
4. **Syncs to S3** - Uploads the built files to your S3 bucket

**Benefits:**
- ✅ No installation or system modifications
- ✅ No sudo/admin privileges required
- ✅ Works in any CI/CD environment with internet access
- ✅ Uses `/bin/sh` for maximum compatibility (no bash required)
- ✅ Clean and portable approach

## Usage

```bash
# Initialize Terraform
terraform init

# Deploy (npm will be auto-installed if needed)
terraform apply
```

That's it! No need to install npm manually in your CI/CD pipeline.

## Variables

- `aws_region`: AWS region (default: "us-east-1")
- `bucket_suffix`: Unique suffix for bucket name (default: "static-site-demo-vite")
- `node_version`: Node.js major version to download if npm is missing (default: "20")

## Outputs

- `website_url`: The HTTP URL of your hosted website
- `bucket_name`: The S3 bucket name

## Pipeline Examples

### GitHub Actions

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
          terraform apply -auto-approve
```

### GitLab CI

```yaml
deploy:
  image: hashicorp/terraform:latest
  script:
    - terraform init
    - terraform apply -auto-approve
  only:
    - main
```

### Qovery / Generic Pipeline

```bash
# Simply run Terraform - npm will be auto-installed if needed
terraform init
terraform apply -auto-approve
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
