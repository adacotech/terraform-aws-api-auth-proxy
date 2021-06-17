# -*- coding: utf-8

import boto3
import json
import os
import logging
from http.cookies import SimpleCookie
from authlib.integrations.requests_client import OAuth2Session
from accept_types import get_best_match

logger = logging.getLogger()
COOKIE_TOKEN_KEY = '_oauth2_token'

def get_federation_id(event) -> str:
    cookie = SimpleCookie()

    cookie.load(', '.join(event['cookies']))
    if 'federation_id' in cookie:
        return cookie['federation_id'].value
    else:
        return ''


def lambda_handler(event, context):
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
   <meta http-equiv="refresh" content="0;URL=/" />
  </head>
  <body />
</html>
''',
                'cookies': [
                    f'{COOKIE_TOKEN_KEY}={access_token}; Secure; HttpOnly; SameSite=Strict; Path=/'                
                ],
                'headers': {
                    'content-type': 'text/html',
                    'location': '/'
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
                }
            }

    except Exception as e:
        import traceback
        logger.warn('client error')
        traceback.print_exc()
        return {
            'statusCode': 400,
            'body': 'Bad Request'
        }
