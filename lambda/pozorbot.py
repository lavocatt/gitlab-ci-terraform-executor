#!/usr/bin/env python
# Lambda function to send telegram messages.
import boto3
import base64
import json
import os
import logging
from botocore.vendored import requests

# Initializing a logger and settign it to INFO.
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_bot_token():
    # Retrieve bot token secret from AWS Secrets Manager.
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=os.environ['AWS_REGION']
    )
    secret_response = client.get_secret_value(
        SecretId=os.environ['SECRET_NAME']
    )
    secrets = json.loads(secret_response)
    return secrets['telegram_bot_token']


# Get the token from Secrets Manager
bot_token = get_bot_token()

# Get chat ID from environment variables.
CHAT_ID = os.environ['CHAT_ID']

# Assemble telegram URL.
TELEGRAM_URL = "https://api.telegram.org/bot{bot_token}/sendMessage"


def lambda_handler(event, context):
    # Handle an incoming SQS message in lambda.

    # Log what we received.
    logger.info(json.dumps(event))

    # Loop over the messages and send them to telegram.
    for record in event['Records']:
        try:
            message = record["body"]
            payload = {
                "text": message.encode("utf8"),
                "chat_id": CHAT_ID
            }
            requests.post(TELEGRAM_URL, payload)
        except Exception as e:
            raise e
