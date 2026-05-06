<p align="center">
  <img src="docs/extras/logo.svg" width="200" alt="WATCHDOG LOGO">
</p>

<p align="center">
  <img src="docs/extras/title.svg" width="500" alt="PROJECT WATCHDOG">
</p>

<p align="center">
  <font color="#00d4ff"><strong>Automated Security Reconnaissance and Intelligence Pipeline</strong></font>
</p>

---

Project Watchdog is a high-performance, automated reconnaissance and vulnerability scanning pipeline. Engineered for speed and scalability, it leverages a serverless AWS architecture to deploy ephemeral, tool-rich scanning environments on demand.

## ARCHITECTURAL OVERVIEW

The system operates on a "Trigger-and-Terminate" model, ensuring maximum cost-efficiency and security isolation.

1.  **Ingress**: A secure webhook hits the API Gateway.
2.  **Orchestration**: AWS Lambda validates the request and provisions an EC2 Spot Instance.
3.  **Bootstrapping**: The instance executes a specialized setup sequence, installing a full suite of security tools in seconds.
4.  **Intelligence Gathering**:
    *   **Network Mapping**: netmalper generates a comprehensive attack surface graph.
    *   **Vulnerability Discovery**: vulnmalper identifies potential entry points.
    *   **AI Synthesis**: malper-analyse uses Large Language Models to interpret raw data into actionable intelligence.
5.  **Exfiltration**: Results are securely pushed to a Supabase backend.
6.  **Alerting**: Real-time status updates are dispatched via Telegram.
7.  **Auto-Destruction**: The instance self-terminates immediately upon completion, leaving no footprint.

---

## KEY CAPABILITIES

*   **Serverless Orchestration**: No idle infrastructure; pay only for active scan time.
*   **AI-Enhanced Analysis**: Moves beyond raw tool output to provide human-readable summaries.
*   **Rapid Deployment**: Tailored bootstrap scripts ensure tools are ready in under 2 minutes.
*   **Isolated Environments**: Every target is scanned in a fresh, dedicated instance.
*   **Instant Visibility**: Telegram integration provides a live "heartbeat" of the scanning process.

---

## REPOSITORY ARCHITECTURE

*   `Scripts/` : The "Brain" - Contains orchestrator and bootstrap logic.
*   `Terraform/` : The "Skeleton" - Defines the entire AWS infrastructure.
*   `docs/` : The "Manual" - Comprehensive guides for deployment and operation.
*   `examples/` : The "Templates" - Payload and configuration examples.

---

## GETTING STARTED

> **Note**: This project requires an active AWS account and API keys for Supabase, OpenRouter, and Telegram.

For complete, step-by-step instructions on deploying the pipeline, please consult our primary documentation:

**[VIEW SETUP GUIDE](docs/setup.md)**

### TRIGGERING A SCAN

Once your infrastructure is live, initiate a scan using a standard HTTP client:

```bash
curl -X POST https://<your-api-endpoint>/scan \
  -H "x-api-key: <your_secret_key>" \
  -H "Content-Type: application/json" \
  -d '{
    "target": "example.com",
    "mode": "normal"
  }'
```

---

## SCAN PROFILES

| Profile | Compute Resource | Performance Characteristics |
|:---|:---|:---|
| **normal** | t3.small | Balanced for speed and cost. |
| **stealth** | t3.large | Rate-limited to avoid detection. |
| **head** | t3.large | Full browser rendering for complex JS targets. |

---

## EXTRAS

*   **[PROJECT LOGO](docs/extras/logo.html)**: Interactive, high-tech HTML/CSS branding for the Watchdog project.

---

## USAGE POLICY

**AUTHORIZED TESTING ONLY.** This software is designed for security professionals and researchers. Usage against targets without explicit permission is strictly prohibited and may be illegal.
