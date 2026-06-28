import boto3
import base64
import json
import os

ec2 = boto3.client('ec2', region_name=os.environ['AWS_REGION'])

MODES = {
    'normal':  {'n_flags': ''},
    'stealth': {'n_flags': '--stealth'},
    'head':    {'n_flags': ''},
}

AMI_ID        = os.environ['AMI_ID']
SUBNET_ID     = os.environ['SUBNET_ID']
SG_ID         = os.environ['SG_ID']
IAM_PROFILE   = os.environ['IAM_PROFILE']

SUPABASE_URL    = os.environ['SUPABASE_URL']
SUPABASE_KEY    = os.environ['SUPABASE_KEY']
SUPABASE_BUCKET = os.environ['SUPABASE_BUCKET']
OPENROUTER_KEY  = os.environ['OPENROUTER_API_KEY']
SETUP_SCRIPT_URL = os.environ['SETUP_SCRIPT_URL']
API_KEY            = os.environ['API_KEY']
TELEGRAM_BOT_TOKEN = os.environ['TELEGRAM_BOT_TOKEN']
TELEGRAM_CHAT_ID   = os.environ['TELEGRAM_CHAT_ID']
GHCR_USER          = os.environ['GHCR_USER']
GHCR_TOKEN         = os.environ['GHCR_TOKEN']


def lambda_handler(event, context):
    headers = event.get('headers', {})
    if headers.get('x-api-key') != API_KEY:
        return {'statusCode': 401, 'body': json.dumps({'error': 'unauthorized'})}

    body = json.loads(event.get('body', '{}'))
    target = body.get('target', '').strip()
    mode   = body.get('mode', 'normal').strip().lower()
    export_json = bool(body.get('export_json', False))
    proxy_lines = body.get('proxy_lines', None)
    if proxy_lines and isinstance(proxy_lines, str):
        # enforce 15 line max server-side too
        lines = [l.strip() for l in proxy_lines.strip().split('\n') if l.strip()][:15]
        proxy_lines = '\n'.join(lines) if lines else None
    else:
        proxy_lines = None

    INSTANCE_TYPE = 't3.small' if mode == 'normal' else 't3.large'

    if not target:
        return {'statusCode': 400, 'body': json.dumps({'error': 'target required'})}

    if mode not in MODES:
        return {'statusCode': 400, 'body': json.dumps({'error': f'invalid mode, pick: {list(MODES.keys())}'})}

    n_flags = MODES[mode]['n_flags']
    proxy_block = ""
    if proxy_lines:
        proxy_block = f"""
cat > /tmp/proxies.txt << 'PROXYEOF'
{proxy_lines}
PROXYEOF
echo "[+] proxies.txt written"
"""

    user_data = f"""#!/bin/bash
export TARGET="{target}"
export MODE="{mode}"
export NETMALPER_FLAGS="{n_flags}"
export EXPORT_JSON="{'true' if export_json else 'false'}"
export GHCR_USER="{GHCR_USER}"
export GHCR_TOKEN="{GHCR_TOKEN}"
export SUPABASE_URL="{SUPABASE_URL}"
export SUPABASE_KEY="{SUPABASE_KEY}"
export SUPABASE_BUCKET="{SUPABASE_BUCKET}"
export OPENROUTER_API_KEY="{OPENROUTER_KEY}"
export TELEGRAM_BOT_TOKEN="{TELEGRAM_BOT_TOKEN}"
export TELEGRAM_CHAT_ID="{TELEGRAM_CHAT_ID}"
{proxy_block}

curl -fsSL {SETUP_SCRIPT_URL} -o /tmp/setup.sh
chmod +x /tmp/setup.sh
bash /tmp/setup.sh >> /var/log/malper.log 2>&1
"""

    user_data_b64 = base64.b64encode(user_data.encode()).decode()

    resp = ec2.run_instances(
        ImageId=AMI_ID,
        InstanceType=INSTANCE_TYPE,
        MinCount=1,
        MaxCount=1,
        SubnetId=SUBNET_ID,
        SecurityGroupIds=[SG_ID],
        IamInstanceProfile={'Name': IAM_PROFILE},
        UserData=user_data_b64,
        BlockDeviceMappings=[
            {
                'DeviceName': '/dev/sda1',
                'Ebs': {
                    'VolumeSize': 25,
                    'VolumeType': 'gp3',
                    'DeleteOnTermination': True
                }
            }
        ],
        InstanceMarketOptions={
            'MarketType': 'spot',
            'SpotOptions': {
                'SpotInstanceType': 'one-time',
                'InstanceInterruptionBehavior': 'terminate',
            }
        },
        TagSpecifications=[{
            'ResourceType': 'instance',
            'Tags': [
                {'Key': 'Name',   'Value': f'malper-{target}'},
                {'Key': 'Target', 'Value': target},
                {'Key': 'Mode',   'Value': mode},
            ]
        }]
    )

    instance_id = resp['Instances'][0]['InstanceId']
    return {
        'statusCode': 200,
        'body': json.dumps({
            'instance_id': instance_id,
            'target': target,
            'mode': mode,
            'export_json': export_json,
            'has_proxies': proxy_lines is not None,
        })
    }
