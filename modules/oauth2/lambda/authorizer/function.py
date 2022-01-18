# -*- coding: utf-8

import boto3
import json
import os
import logging
from authlib.jose import jwt
from http.cookies import SimpleCookie
import requests
import time

logger = logging.getLogger()
COOKIE_TOKEN_KEY = os.environ['COOKIE_TOKEN_KEY']

def get_authorization_token(event) -> str:
    cookie = SimpleCookie()

    cookie.load(', '.join(event['cookies']))
    if COOKIE_TOKEN_KEY in cookie:
        return cookie[COOKIE_TOKEN_KEY].value

    header = event['headers'].get('authorization')
    if header is None:
        return None

    return header.replace('Bearer ', '')
    

def lambda_handler(event, _context):
    issuer = os.environ['OAUTH2_ISSUER']
    audience = os.environ.get('OAUTH2_AUDIENCE')
    scope = os.environ.get('OAUTH2_SCOPE', '')
    required_scopes = set(scope.split(' '))
    try:
        tablename = os.environ['DYNAMODB_TABLE_NAME']
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table(tablename)
        logger.warn(event)
        token = get_authorization_token(event)
        logger.warn(token)

        # public key from dynamodb
        res = table.get_item(Key={
            'pk': issuer
        },
        AttributesToGet=['jwks'])
        jwks = None

        if 'Item' in res:
            jwks = json.loads(res['Item']['jwks'])
        else:
            # public key from jwk
            jwks = requests.get('{}.well-known/jwks.json'.format(issuer)).json()
            # put to dynamodb
            ttl = int(time.time()) + 600
            
            table.put_item(Item={
                'pk': issuer,
                'jwks': json.dumps(jwks),
                'ttl': ttl
            })

        audiences = [issuer]

        if audience is not None:
            audiences.append(audience)

        claim = jwt.decode(
            token,
            jwks,
            claims_options={
                'iss': {'essential': True, 'values': issuer},
                'aud': {'essential': True, 'values': audiences}
            }
        )

        claim.validate()

        if scope != '':
            scope_value = claim.get('scope')
            logger.warn(scope_value)
            if scope_value is None:
                raise Exception('enough scope')
            
            scopes = set(scope_value.split(' '))
            logger.warn(scopes)
            logger.warn(required_scopes)
            if not required_scopes <= scopes:
                raise Exception('enough scope')
        return {
            'isAuthorized': True
        }
    except Exception as e:
        import traceback
        logger.error('auth error')
        traceback.print_exc()

        return {'isAuthorized': False}
