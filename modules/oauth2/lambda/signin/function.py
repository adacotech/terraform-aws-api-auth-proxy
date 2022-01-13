# -*- coding: utf-8

import boto3
import os
import logging
import secrets
import time
import json
from http.cookies import SimpleCookie
from authlib.integrations.requests_client import OAuth2Session
from accept_types import get_best_match

logger = logging.getLogger()
COOKIE_FEDERATION_KEY = os.environ['COOKIE_FEDERATION_KEY']
COOKIE_TOKEN_KEY = os.environ['COOKIE_TOKEN_KEY']

def signin(event, context):
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
            f'{COOKIE_FEDERATION_KEY}={federation_id}; Secure; HttpOnly; SameSite=Lax; Path=/'
        ],
        "headers": {
            "Location": target_uri
        }
    }


def get_federation_id(event) -> str:
    cookie = SimpleCookie()

    cookie.load(', '.join(event['cookies']))
    if COOKIE_FEDERATION_KEY in cookie:
        return cookie[COOKIE_FEDERATION_KEY].value
    else:
        return ''


def callback(event, context):
    issuer = os.environ['OAUTH2_ISSUER']
    required_scope = os.environ.get('OAUTH2_SCOPE')
    redirect_uri = os.environ['REDIRECT_URI']
    client_id = os.environ['OAUTH2_CLIENT_ID']
    token_endpoint = os.environ.get('OAUTH2_TOKEN_ENDPOINT', f'{issuer}/oauth/token')
    uri = f'{redirect_uri}?{event["rawQueryString"]}'
    try:
        client = OAuth2Session(client_id=client_id,
                           client_secret=None,
                           redirect_uri=redirect_uri,
                           scope=required_scope)
        tablename = os.environ['DYNAMODB_TABLE_NAME']
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(tablename)

        federation_id = get_federation_id(event)

        res = table.get_item(Key={
            'pk': federation_id
        },
        AttributesToGet=['state', 'code_verifier'])

        item = res['Item']

        token = client.fetch_token(token_endpoint,
                        authorization_response=uri,
                        state=item['state'],
                        code_verifier=item['code_verifier'])

        access_token = token['access_token']

        table.delete_item(Key={'pk': federation_id})
        accept_header = event['headers'].get('accept')

        return_type = get_best_match(accept_header, ['text/html', 'application/json'])

        if return_type == 'text/html':
            # for browser
            return {
                'isBase64Encoded': False,
                'statusCode': 200,
                'body': '''
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
   <meta http-equiv="refresh" content="0;URL=/api_authorize/success" />
  </head>
  <body />
</html>
''',
                'cookies': [
                    f'{COOKIE_TOKEN_KEY}={access_token}; Secure; HttpOnly; SameSite=Strict; Path=/',
                    f'{COOKIE_FEDERATION_KEY}=; Secure; HttpOnly; SameSite=Lax; Path=/; Max-Age=0'
                ],
                'headers': {
                    'content-type': 'text/html'
                }
            }
        else:
            # for application
            return {
                'isBase64Encoded': False,
                'statusCode': 200,
                'body': json.dumps(token),
                'headers': {
                    'content-type': 'application/json'
                },
                'cookies': [
                    f'{COOKIE_FEDERATION_KEY}=; Secure; HttpOnly; SameSite=Lax; Path=/; Max-Age=0'
                ]
            }

    except Exception as e:
        import traceback
        logger.warn('client error')
        traceback.print_exc()
        return {
            'statusCode': 400,
            'body': 'Bad Request'
        }


def success(event, context):
    return {
        'statusCode': 303,
        'headers': {
            'location': '/'
        }
    }


def lambda_handler(event, context):
    # routing
    if event["rawPath"] == "/api_authorize/signin":
        return signin(event, context)
    elif event["rawPath"] == "/api_authorize/callback":
        return callback(event, context)
    elif event["rawPath"] == "/api_authorize/success":
        return success(event, context)
    else:
        return {
            'statusCode': 404,
            'body': 'Not found'
        }
