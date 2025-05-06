# AWS Org CloudTrail ➜ EventBridge ➜ Lambda ➜ Splunk

Monitors **all AWS accounts in your Organization** by streaming CloudTrail events
to Splunk over HTTP Event Collector (HEC).  
Resiliency extras:

- Monitors **all AWS accounts in your Organization** by streaming CloudTrail events
- to Splunk over HTTP Event Collector (HEC).
+ Streams **IAM Access Analyzer findings** from every AWS account in
+ your Organization straight to Splunk over HTTP Event Collector (HEC).

Tested with **Terraform 1.6+** and **AWS provider ≥ 5.0**.

In order for the orginazational analyzer to be deployed. The following must be ran agaist the organizational master account:

```bash
# Enables access analyzer for organizational use
aws organizations enable-aws-service-access \
     --service-principal access-analyzer.amazonaws.com

# Assigns specific account delegated priveldges for access analyzer
aws organizations register-delegated-administrator \
     --account-id 111122223333 \
     --service-principal access-analyzer.amazonaws.com

# Needed for delegate access
aws iam create-service-linked-role \
     --aws-service-name access-analyzer.amazonaws.com
```


Access-Analyzer finding
            │
  EventBridge →  primary Lambda ────► Splunk
            │            │
            │            └─ failure → primary SQS queue
            └─ Invoke error (5xx, timeout, etc.)
                             │
                             ▼
                      DLQ (encrypted)
                             │
                      ─ poll each 5 s ─
                             │
                replay-Lambda-replay ───► Splunk
                             │
                 if still fails, message stays in DLQ
