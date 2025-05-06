import json, time, os, logging, urllib3, boto3
from typing import Dict, Any

http   = urllib3.PoolManager()
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def _load_hec_token() -> str:
    """
    Load Splunk HEC token from Secrets Manager or SSM or env var (fallback)
    """
    secret_arn = os.getenv("HEC_TOKEN_SECRET_ARN", "")
    ssm_path   = os.getenv("HEC_TOKEN_SSM_PATH", "")
    if secret_arn:
        sm = boto3.client("secretsmanager")
        return sm.get_secret_value(SecretId=secret_arn)["SecretString"]
    if ssm_path:
        ssm = boto3.client("ssm")
        return ssm.get_parameter(Name=ssm_path, WithDecryption=True)["Parameter"]["Value"]
    return os.environ["SPLUNK_HEC_TOKEN"]  # dev fallback

SPLUNK_HEC_ENDPOINT = os.environ["SPLUNK_HEC_ENDPOINT"]
SPLUNK_HEC_TOKEN    = _load_hec_token()

def _real_send(payload: Dict[str, Any]):
    """
    Dry-run mode: skip the HTTP POST when HEC_TEST_MODE=true
    """
    encoded = json.dumps(payload).encode()
    resp = http.request(
        "POST",
        SPLUNK_HEC_ENDPOINT,
        headers={
            "Authorization": f"Splunk {SPLUNK_HEC_TOKEN}",
            "Content-Type": "application/json",
        },
        body=encoded,
        timeout=urllib3.Timeout(connect=2.0, read=9.0),
        retries=False,
    )
    if resp.status >= 300:
        raise RuntimeError(f"Splunk HEC rejected event: {resp.status} :: {resp.data}")

# def _dry_run(payload: Dict[str, Any]):
#     logger.info("DRY-RUN: would POST %d bytes to %s", len(json.dumps(payload)), SPLUNK_HEC_ENDPOINT)

def _dry_run(payload: Dict[str, Any]):
    pretty = json.dumps(payload, indent=2)
    logger.info("DRY-RUN: would POST %d bytes to %s", len(pretty), SPLUNK_HEC_ENDPOINT)
    logger.info("DRY-RUN payload:\n%s", pretty)

send_to_splunk = _dry_run if os.getenv("HEC_TEST_MODE", "").lower() == "true" else _real_send

def _to_splunk_event(detail: Dict[str, Any]) -> Dict[str, Any]:
    """
    Helper to convert AWS event to Splunk HEC event
    """
    return {
        "time": int(time.time()),
        "host": detail.get("accountId", "unknown"),
        "source": "aws:accessanalyzer",
        "sourcetype": "aws:accessanalyzer:finding",
        "event": detail,
    }

def lambda_handler(event, _context):
    try:
        logger.debug("Received event %s", json.dumps(event)[:1000])

        # EventBridge may wrap a single finding or an array
        records = event.get("detail") or event.get("Records") or [event]
        if not isinstance(records, list):
            records = [records]

        for record in records:
            send_to_splunk(_to_splunk_event(record))

        return {"status": "ok", "records_sent": len(records)}

    except Exception as exc:
        logger.exception("Failed to forward event to Splunk")
        # Raising lets Lambda/SQS DLQ capture the failure
        raise exc
