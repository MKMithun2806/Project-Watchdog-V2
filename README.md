# Project Watchdog V2

Project Watchdog is an automated reconnaissance and vulnerability scanning pipeline designed for efficiency and scalability. It leverages AWS serverless components to trigger ephemeral scanning environments, storing results in a central database and providing real-time updates via Telegram.

## Overview

The system is triggered via a webhook, which initiates a specialized pipeline:

1.  **Orchestration**: AWS Lambda validates the request and launches an EC2 Spot Instance.
2.  **Environment Setup**: The EC2 instance automatically bootstraps itself with necessary tools and dependencies.
3.  **Execution**: A series of security tools (netmalper, vulnmalper, malper-analyse) are executed in sequence.
4.  **AI Analysis**: Results are analyzed using LLMs via OpenRouter to provide actionable insights.
5.  **Storage**: Final reports and metadata are pushed to Supabase.
6.  **Reporting**: Real-time status updates and completion alerts are sent via Telegram.
7.  **Cleanup**: The EC2 instance terminates itself immediately upon completion or failure.

## Key Features

*   **Automated Workflow**: Hands-off scanning from trigger to report.
*   **Cost Efficiency**: Utilizes AWS Spot Instances and serverless architecture.
*   **Comprehensive Scanning**: Integrates network mapping, vulnerability detection, and AI-driven analysis.
*   **Real-time Notifications**: Instant feedback on scan progress via Telegram.
*   **Scalable Architecture**: Independent environments for each scan target.

## Repository Structure

*   `Scripts/`: Contains the orchestration and setup scripts for EC2 instances.
*   `Terraform/`: Infrastructure as Code (IaC) files for deploying the AWS environment.
*   `docs/`: Detailed documentation and setup guides.
*   `examples/`: Sample configurations and payloads.

## Prerequisites

*   AWS Account with appropriate permissions.
*   Supabase project for data storage.
*   OpenRouter API key for analysis.
*   Telegram Bot for notifications.
*   Terraform and AWS CLI for deployment.

## Getting Started

For detailed installation and configuration instructions, please refer to the [Setup Guide](docs/setup.md).

### Quick Trigger

Once deployed, a scan can be initiated with a simple POST request:

```bash
curl -X POST https://<api-endpoint>/scan \
  -H "x-api-key: <your_secret_key>" \
  -H "Content-Type: application/json" \
  -d '{
    "target": "example.com",
    "mode": "normal"
  }'
```

## Scan Modes

| Mode | Instance Type | Description |
|------|---------------|-------------|
| normal | t3.small | Standard scanning profile. |
| stealth | t3.large | Rate-limited, polite scanning. |
| head | t3.large | Polite scanning with headless browser capabilities. |

## License

This project is intended for authorized security testing and research purposes only.
