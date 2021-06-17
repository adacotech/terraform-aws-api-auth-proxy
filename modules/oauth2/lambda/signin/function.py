# -*- coding: utf-8

import boto3
import os
import logging
import secrets
import time
from authlib.integrations.requests_client import OAuth2Session

logger = logging.getLogger()

def lambda_handler(event, context):
    issuer = os.environ['OAUTH2_ISSUER']
    audience = os.environ.get('OAUTH2_AUDIENCE')
    required_scope = os.environ.get('OAUTH2_SCOPE')
    redirect_uri = os.environ['REDIRECT_URI']
    client_id = os.environ['OAUTH2_CLIENT_ID']

    authorization_endpoint = os.environ.get('OAUTH2_AUTHORIZATION_ENDPOINT', f'{issuer}/authorize')

    code_verifier = secrets.token_urlsafe(96)[:128]
    federation_id = secrets.token_urlsafe(96)


    client = OAuth2Session(client_id=client_id,
                           client_secret=None,
                           redirect_uri=redirect_uri,
                           scope=required_scope)
    tablename = os.environ['DYNAMODB_TABLE_NAME']
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(tablename)

    target_uri, state = client.create_authorization_url(url=authorization_endpoint,
                                                        state=None,
                                                        code_verifier=code_verifier,
                                                        audience=audience)

    ttl = int(time.time()) + 600
    
    table.put_item(Item={
        'pk': federation_id,
        'state': state,
        'code_verifier': code_verifier,
        'ttl': ttl
    })
    
    return {
        "statusCode": 302,
        "cookies": [
            f'federation_id={federation_id}; Secure; HttpOnly; SameSite=Lax; Path=/'
        ],
        "headers": {
            "Location": target_uri
        }
    }

