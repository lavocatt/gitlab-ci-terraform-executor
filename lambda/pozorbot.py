#!/usr/bin/env python
# Lambda function to send telegram messages.
import json
import os
import logging
from botocore.vendored import requests

# Initializing a logger and settign it to INFO.
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Get data from environment variables.
TOKEN = os.environ['TOKEN']
CHAT_ID = os.environ['CHAT_ID']
TELEGRAM_URL = "https://api.telegram.org/bot{}/sendMessage".format(TOKEN)


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
