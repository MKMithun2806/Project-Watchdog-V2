# Setup Guide - Project Watchdog V2

This guide provides step-by-step instructions for deploying and configuring the Watchdog automated reconnaissance pipeline.

## Prerequisites

Before starting the deployment, ensure you have the following accounts and tools ready:

1.  **AWS Account**: Permissions to manage Lambda, EC2 (Spot Instances), API Gateway, IAM, and Security Groups.
2.  **Supabase Account**: A project for storing scan results and metadata.
3.  **OpenRouter Account**: API key for the AI analysis phase (malper-analyse).
4.  **Telegram Bot**: A bot token and your chat ID for real-time notifications.
5.  **Local Tools**: Terraform and AWS CLI installed and configured.

---

## 1. Supabase Configuration

### Storage Bucket
- Create a private bucket named `recon-reports` (or your preferred name).
- Note the bucket name for the `supabase_bucket` variable.

### Database Table
Create a table named `recon_scans` with the following schema:

```sql
CREATE TABLE recon_scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target TEXT NOT NULL,
    scan_date TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'completed',
    graph_url TEXT,
    report_url TEXT,
    summary_url TEXT,
    notes TEXT
);
```

Disable Row Level Security (RLS) for the `recon_scans` table if you want the Lambda/EC2 to write directly, or configure appropriate service-role policies.

---

## 2. Telegram Bot Setup

1.  Message `@BotFather` on Telegram to create a new bot and obtain the **Bot Token**.
2.  Start a chat with your bot.
3.  Get your **Chat ID** by messaging `@userinfobot` or checking the bot's updates via API.

---

## 3. Infrastructure Deployment (Terraform)

### Configuration
1.  Navigate to the `Terraform/` directory.
2.  Copy `example.terraform.tfvars` to `terraform.tfvars`.
3.  Fill in the required variables:

| Variable | Description |
|----------|-------------|
| `aws_region` | Target AWS region (e.g., `ap-southeast-1`). |
| `ami_id` | Ubuntu 24.04 x86_64 AMI ID for your region. |
| `subnet_id` | A public subnet ID in your default VPC. |
| `supabase_url` | Your Supabase project URL. |
| `supabase_key` | Supabase service role key (secret). |
| `openrouter_api_key` | OpenRouter API key. |
| `api_key` | A custom secret string for API Gateway authorization. |
| `telegram_bot_token` | Your Telegram bot token. |
| `telegram_chat_id` | Your Telegram chat ID. |
| `setup_script_url` | Raw GitHub URL for `Scripts/setup.sh`. |

### Initialization and Deployment
Run the following commands:

```bash
terraform init
terraform plan
terraform apply
```

Upon success, Terraform will output the `api_endpoint`. This is the URL used to trigger scans.

---

## 4. Operational Details

### Triggering a Scan
Send a POST request to the `api_endpoint`:

- **Header**: `x-api-key: <your_api_key>`
- **Body**:
  ```json
  {
    "target": "example.com",
    "mode": "normal"
  }
  ```

### Available Modes
- `normal`: Standard scan (t3.small).
- `stealth`: Polite scan (t3.large).
- `head`: Headless polite scan (t3.large).

---

## 5. Troubleshooting and Maintenance

### Monitoring
- **Telegram**: Real-time status updates for each phase.
- **CloudWatch**: Lambda execution logs (`/aws/lambda/malper-launcher`).
- **AWS SSM**: Connect to running EC2 instances without SSH:
  ```bash
  aws ssm start-session --target <instance-id>
  ```
- **EC2 Logs**: View logs on the instance at `/var/log/malper.log`.

### Self-Termination
The EC2 instances are designed to be ephemeral. They will automatically terminate themselves after the pipeline finishes or if a failure occurs.
