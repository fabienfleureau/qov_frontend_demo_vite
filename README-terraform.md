# Terraform S3 Static Website Deployment

This Terraform configuration deploys a Vite application to AWS S3 with static website hosting.

## Prerequisites

- AWS CLI installed
- AWS credentials configured
- Terraform installed
- **Optional:** Node.js and npm (will be auto-installed if missing)

## How It Works

The Terraform configuration automatically handles npm using **portable Node.js binaries**:

1. **Checks for npm** - Uses existing npm if available
2. **Downloads portable Node.js** - If npm is missing:
   - Detects libc implementation (glibc vs musl)
   - Downloads appropriate Node.js binary:
     - **Alpine/musl**: Uses musl-compiled binaries (`node-vX.Y.Z-linux-x64-musl.tar.gz`)
     - **Debian/Ubuntu**: Uses standard glibc binaries
   - Extracts to `/tmp`
3. **Builds the app** - Runs `npm install && npm run build`
4. **Syncs to S3** - Uploads built files

**Benefits:**
- ✅ Works on Alpine Linux (musl) and glibc-based systems
- ✅ No installation or system modifications needed
- ✅ No sudo/admin privileges required
- ✅ Automatically selects correct binary for your environment

## Usage

### Simple approach: Let Terraform handle everything

```bash
# Terraform will auto-download Node.js and build
terraform init
terraform apply
```

### Alternative: Pre-build approach

```bash
# Build the application first
npm install
npm run build

# Deploy with Terraform (skips build)
terraform init
terraform apply -var="skip_build=true"
```

Both approaches work reliably now that musl binaries are supported!

## Variables

- `aws_region`: AWS region (default: "us-east-1")
- `bucket_suffix`: Unique suffix for bucket name (default: "static-site-demo-vite")
- `node_version`: Node.js major version to download if npm is missing (default: "20")
- `skip_build`: Skip the build step, use pre-built dist folder (default: false)

## Outputs

- `website_url`: The HTTP URL of your hosted website
- `bucket_name`: The S3 bucket name

## Pipeline Examples

### GitHub Actions (Simple approach - auto-build)

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

### GitLab CI (Simple approach - auto-build)

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
# Simple: Terraform handles everything
terraform init
terraform apply -auto-approve
```

## Troubleshooting

### Build fails with "npm: not found"

This shouldn't happen as npm is automatically downloaded. Check:
- Internet connectivity (needs access to nodejs.org)
- `/tmp` directory is writable
- Architecture is supported (x64, arm64, armv7l on Linux/macOS)
- Either `curl` or `wget` is available

### "Neither curl nor wget found" error

Install curl or wget:
```bash
apk add curl  # Alpine
apt-get install -y curl  # Debian/Ubuntu
```

### "Node.js binary not found" error

The script automatically detects musl vs glibc and downloads the correct binary. If this fails:
- Check the Node.js version supports musl binaries (v16.17.0+)
- Try the pre-build approach with `skip_build=true`

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
