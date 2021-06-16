# -*- coding: utf-8

import boto3
import base64
import json
import os
import logging
from authlib.jose import jwt
from http.cookies import SimpleCookie
import requests

logger = logging.getLogger()
COOKIE_TOKEN_KEY = '_oauth2_token'

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
    required_scopes = set(os.environ.get('OAUTH2_SCOPE', '').split(' '))
    try:
        logger.warn(event)
        token = get_authorization_token(event)
        logger.warn(token)

        # public key from jwk
        jwks = requests.get('{}.well-known/jwks.json'.format(issuer)).json()

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

        if len(required_scopes) >= 0:
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
        
        return {
            'isAuthorized': True,
            'context': {
                'cookie': f'{COOKIE_TOKEN_KEY}={token}; Secure; HttpOnly; SameSite=Strict; Path=/'
            }
        }
    except Exception as e:
        import traceback
        logger.error('auth error')
        traceback.print_exc()

        return {'isAuthorized': False}
