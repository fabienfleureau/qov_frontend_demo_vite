# Terraform S3 Static Website Deployment

This Terraform configuration deploys a Vite application to AWS S3 with static website hosting.

## Prerequisites

- AWS CLI installed
- AWS credentials configured
- Terraform installed
- **Optional:** Node.js and npm (will be auto-installed if missing)

## How It Works

The Terraform configuration automatically handles npm installation:

1. **Checks for npm** - If npm is already installed, it uses it
2. **Auto-installs Node.js** - If npm is missing, it automatically installs Node.js based on your OS:
   - Debian/Ubuntu: Uses `apt-get`
   - RHEL/CentOS/Amazon Linux: Uses `yum`
   - Alpine Linux: Uses `apk`
3. **Builds the app** - Runs `npm install && npm run build`
4. **Syncs to S3** - Uploads the built files to your S3 bucket

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
- `node_version`: Node.js version to install if npm is missing (default: "20")

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

### "npm: not found" error

**Solution 1 (Recommended):** Ensure Docker is available in your pipeline
**Solution 2:** Use `skip_build=true` and build separately
**Solution 3:** Install Node.js in your pipeline before running Terraform

### "docker: not found" error

Either:
- Enable Docker in your CI/CD pipeline
- Use pre-build approach with `skip_build=true`
- Install npm directly in the pipeline

## Clean Up

```bash
terraform destroy
```
