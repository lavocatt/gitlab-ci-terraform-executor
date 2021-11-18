#!/usr/bin/env python
# Lambda function to send telegram messages.
import boto3
import json
import os
import logging
import urllib3

# Initializing a logger and settign it to INFO.
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def get_slack_url():
    # Retrieve bot token secret from AWS Secrets Manager.
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=os.environ['SECRET_REGION']
    )
    secret_response = client.get_secret_value(
        SecretId=os.environ['SECRET_NAME']
    )
    secrets = json.loads(secret_response['SecretString'])
    return secrets['slack_url']


def send_message(payload):
    # Send a message to telegram.
    http = urllib3.PoolManager()
    headers = {"Content-Type": "application/json"}
    http.request(
        'POST',
        get_slack_url(),
        body=json.dumps(payload),
        headers=headers,
        retries=3
    )


def lambda_handler(event, context):
    # Handle an incoming SQS message in lambda.

    # Log what we received.
    logger.info(json.dumps(event))

    # Loop over the messages and send them to telegram.
    for record in event['Records']:
        try:
            payload = {
                "text": record["body"]
            }
            send_message(payload)

        except Exception as e:
            raise e
