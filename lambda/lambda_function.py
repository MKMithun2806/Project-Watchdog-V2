import boto3
import base64
import json
import os

ec2 = boto3.client('ec2', region_name=os.environ['AWS_REGION'])

MODES = {
    'normal':  '',
    'stealth': 'stealth',
    'head':    'head',
}

AMI_ID        = os.environ['AMI_ID']
INSTANCE_TYPE = 't3.large'
SUBNET_ID     = os.environ['SUBNET_ID']
SG_ID         = os.environ['SG_ID']
IAM_PROFILE   = os.environ['IAM_PROFILE']

SUPABASE_URL    = os.environ['SUPABASE_URL']
SUPABASE_KEY    = os.environ['SUPABASE_KEY']
SUPABASE_BUCKET = os.environ['SUPABASE_BUCKET']
OPENROUTER_KEY  = os.environ['OPENROUTER_API_KEY']
SETUP_SCRIPT_URL = os.environ['SETUP_SCRIPT_URL']  # GitHub raw URL for setup.sh


def lambda_handler(event, context):
    body = json.loads(event.get('body', '{}'))
    target = body.get('target', '').strip()
    mode   = body.get('mode', 'normal').strip().lower()

    if not target:
        return {'statusCode': 400, 'body': json.dumps({'error': 'target required'})}

    if mode not in MODES:
        return {'statusCode': 400, 'body': json.dumps({'error': f'invalid mode, pick: {list(MODES.keys())}'})}

    user_data = f"""#!/bin/bash
export TARGET="{target}"
export MODE="{mode}"
export SUPABASE_URL="{SUPABASE_URL}"
export SUPABASE_KEY="{SUPABASE_KEY}"
export SUPABASE_BUCKET="{SUPABASE_BUCKET}"
export OPENROUTER_API_KEY="{OPENROUTER_KEY}"

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
        })
    }
