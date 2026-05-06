# DEPLOYMENT AND SETUP GUIDE
---
### Project Watchdog V2 Installation Manual
---

This document provides the definitive procedure for deploying the Watchdog infrastructure. Follow these steps sequentially to ensure a successful integration.

## 1. PRE-FLIGHT REQUIREMENTS

Ensure you have active accounts and access keys for the following services:

*   **AWS CLOUD**: Permissions for Lambda, EC2 (Spot), API Gateway, and IAM.
*   **SUPABASE**: A project for database storage and file hosting.
*   **OPENROUTER**: API access for AI analysis.
*   **TELEGRAM**: A bot token for real-time reporting.

---

## 2. COMPONENT CONFIGURATION

### A. SUPABASE BACKEND
Watchdog requires a central repository for scan metadata and raw reports.

1.  **Storage**: Create a private bucket named `recon-reports`.
2.  **Database**: Execute the following SQL in your Supabase SQL Editor:

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

> **Warning**: Ensure your Row Level Security (RLS) policies allow service-role access, or disable RLS for the `recon_scans` table if the environment is strictly private.

### B. TELEGRAM NOTIFICATIONS
1.  Obtain a **Bot Token** from `@BotFather`.
2.  Obtain your **Chat ID** (the destination for scan alerts).

---

## 3. INFRASTRUCTURE DEPLOYMENT

### STEP 1: PREPARE ENVIRONMENT VARIABLES
Navigate to the `Terraform/` directory and create your secrets file:

```bash
cp example.terraform.tfvars terraform.tfvars
```

### STEP 2: CONFIGURE VARIABLES
Edit `terraform.tfvars` with your specific parameters:

| Variable | Description |
|:---|:---|
| `aws_region` | The AWS region (e.g., `ap-southeast-1`). |
| `ami_id` | Ubuntu 24.04 x86_64 AMI ID. |
| `subnet_id` | A public subnet with internet egress. |
| `api_key` | **CRITICAL**: Your custom authorization secret. |
| `setup_script_url` | The raw GitHub URL to `Scripts/setup.sh`. |

### STEP 3: INITIALIZE AND APPLY
Run the deployment sequence:

```bash
terraform init
terraform plan
terraform apply
```

> **Important**: Upon completion, Terraform will output your `api_endpoint`. Save this URL.

---

## 4. VERIFICATION AND TESTING

To confirm the pipeline is operational, send a test payload:

```bash
curl -X POST <YOUR_API_ENDPOINT> \
  -H "x-api-key: <YOUR_API_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"target": "scanme.nmap.org", "mode": "normal"}'
```

**What to expect:**
1.  **Instantly**: You should receive a 200 OK response with an instance ID.
2.  **Within 2-5 mins**: A "Malper Online" notification on Telegram.
3.  **Completion**: Links to the attack surface graph and AI report will appear on Telegram and in Supabase.

---

## 5. MAINTENANCE AND DEBUGGING

*   **Lambda Logs**: Check CloudWatch Logs for `/aws/lambda/malper-launcher`.
*   **Instance Debugging**: Use AWS SSM for secure console access:
    ```bash
    aws ssm start-session --target <instance-id>
    ```
*   **Live Pipeline Logs**: On the EC2 instance, monitor progress at `/var/log/malper.log`.

---
**[RETURN TO MAIN README](../README.md)**
