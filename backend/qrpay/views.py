"""Prototype backup API. There is no bank/payment execution endpoint."""
import hashlib
import json
import secrets
from datetime import timedelta
from functools import wraps
from django.conf import settings
from django.contrib.auth import authenticate, get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.db import transaction, IntegrityError
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from .models import AccessToken, Backup, RateLimit

class BadInput(ValueError):
    pass

def string(value, limit, *, required=False, multiline=False):
    if not isinstance(value, str) or len(value) > limit or (required and not value.strip()):
        raise BadInput('Invalid text field.')
    if any(ord(c) < 32 and not (multiline and c in '\n\r\t') for c in value):
        raise BadInput('Control characters are not accepted.')
    return value

def validate_snapshot(value):
    if not isinstance(value, dict) or set(value) - {'displayName','budget','activity','qrs','feedback','goals','bankLabel','simLabel'}:
        raise BadInput('Unsupported backup fields.')
    for key, limit in [('displayName',60),('bankLabel',40),('simLabel',40),('budget',7)]:
        if key in value:
            string(value[key],limit)
    budget = value.get('budget','')
    if budget and (not budget.isdigit() or not 1 <= int(budget) <= 1000000):
        raise BadInput('Invalid budget.')
    for field in ['activity','qrs','feedback','goals']:
        entries = value.get(field, [])
        if not isinstance(entries,list) or len(entries)>2000:
            raise BadInput('Too many records.')
        seen = set()
        for row in entries:
            if not isinstance(row,dict):
                raise BadInput('Invalid record.')
            ident = string(row.get('id'),100,required=True)
            if ident in seen:
                raise BadInput('Duplicate record id.')
            seen.add(ident)
            allowed = {
              'activity': {'id','name','kind','bank','amountMinor','note','reference','status','createdAt','category','demo'},
              'qrs': {'id','raw','name','kind','amountMinor','createdAt'},
              'feedback': {'id','text','createdAt','appVersion','status'},
              'goals': {'id','name','target','saved'},
            }[field]
            if set(row)-allowed:
                raise BadInput('Unsupported record fields.')
            required = allowed - ({'appVersion'} if field=='feedback' else set())
            if required-set(row):
                raise BadInput('Missing record fields.')
            if field in ('activity','qrs') and row.get('kind') not in ('pay','transfer'):
                raise BadInput('Invalid transaction type.')
            for k,v in row.items():
                if isinstance(v,str):
                    string(v, 2048 if k=='raw' else 2000 if k=='text' else 120, multiline=(k=='text'))
            if field=='activity':
                if row.get('demo') is not True or row.get('kind') not in ('pay','transfer'):
                    raise BadInput('Only demo records are supported by this prototype.')
                if row.get('status') not in ('demoSuccess','declined','unknown'):
                    raise BadInput('Invalid demo result.')
            if field in ('activity','qrs'):
                if type(row.get('amountMinor')) is not int or not (0 if field=='qrs' else 1) <= row['amountMinor'] <= 1000000:
                    raise BadInput('Invalid amount.')
            if field=='goals':
                string(row.get('name'),60,required=True)
                if type(row.get('target')) is not int or not 1 <= row['target'] <= 1000000:
                    raise BadInput('Invalid savings target.')
                if type(row.get('saved')) is not int or not 0 <= row['saved'] <= 1000000:
                    raise BadInput('Invalid savings contribution.')
            if field=='qrs':
                try:
                    qr=json.loads(row['raw'])
                    if not isinstance(qr,dict) or qr.get('schema') not in ('qrpay-demo','qrpay-demo-v2'):
                        raise BadInput('Invalid QR schema.')
                    if set(qr)-{'schema','v','bank','merchant','name','amountMinor','currency','reference','expiresAt','kind','note'}:
                        raise BadInput('Unexpected QR fields.')
                except (KeyError,TypeError,json.JSONDecodeError) as exc:
                    raise BadInput('Invalid QR data.') from exc
    return value

def throttle(request, username):
    # Database-backed rate limit survives process restart and multiple workers.
    raw = f"{request.META.get('REMOTE_ADDR','')}:{username.lower()}"
    key = hashlib.sha256(raw.encode()).hexdigest()
    with transaction.atomic():
        row,_=RateLimit.objects.select_for_update().get_or_create(key=key, defaults={'started':timezone.now()})
        if row.started < timezone.now()-timedelta(minutes=15):
            row.started=timezone.now();row.count=0
        row.count += 1;row.save()
        return row.count <= 10

def issue_token(user):
    token = secrets.token_urlsafe(32)
    AccessToken.objects.filter(user=user).delete()
    AccessToken.objects.create(user=user,digest=hashlib.sha256(token.encode()).hexdigest(),expires=timezone.now()+timedelta(days=30))
    return {'token':token,'username':user.username}

@csrf_exempt
def api(request, action):
    if request.method != 'POST':
        return JsonResponse({'error':'POST required.'},status=405)
    if request.content_type != 'application/json':
        return JsonResponse({'error':'JSON required.'},status=415)
    try:
        if len(request.body)>4*1024*1024:
            return JsonResponse({'error':'Request too large.'},status=413)
        data=json.loads(request.body)
        if not isinstance(data,dict):
            raise BadInput('JSON object required.')
        if action=='updates':
            return JsonResponse({'version':'0.4.0','message':'Install signed APK updates through your project build.'})
        if action in ('register','login'):
            username=string(data.get('username'),60,required=True).strip()
            password=string(data.get('password'),128,required=True)
            if not throttle(request,username):
                return JsonResponse({'error':'Too many attempts. Try again in 15 minutes.'},status=429)
            if action=='register':
                user=get_user_model()(username=username)
                try:
                    user.full_clean(exclude=['password']);validate_password(password,user)
                    user.set_password(password);user.save()
                except (ValidationError,IntegrityError):
                    return JsonResponse({'error':'Account cannot be created. Use a unique username and a strong password of at least 12 characters.'},status=400)
            else:
                user=authenticate(username=username,password=password)
                if user is None:
                    return JsonResponse({'error':'Invalid app account credentials.'},status=401)
            return JsonResponse(issue_token(user))
        digest=hashlib.sha256(request.headers.get('Authorization','').removeprefix('Bearer ').encode()).hexdigest()
        token=AccessToken.objects.filter(digest=digest,expires__gt=timezone.now()).select_related('user').first()
        if token is None:
            return JsonResponse({'error':'Sign in again.'},status=401)
        if action=='logout':
            token.delete();return JsonResponse({'ok':True})
        if action=='delete-account':
            token.user.delete();return JsonResponse({'ok':True})
        if action=='insights':
            return JsonResponse({'eligible':False,'reason':'Demo transactions are excluded. No verified live records exist.'})
        if action not in ('sync','restore'):
            return JsonResponse({'error':'Unknown endpoint.'},status=404)
        with transaction.atomic():
            row,_=Backup.objects.select_for_update().get_or_create(user=token.user)
            if action=='restore':
                return JsonResponse({'revision':row.revision,'snapshot':row.snapshot})
            snapshot=validate_snapshot(data.get('snapshot'))
            request_id=string(data.get('requestId'),100,required=True)
            if request_id==row.last_request:
                return JsonResponse({'revision':row.revision})
            if type(data.get('revision')) is not int or data['revision']!=row.revision:
                return JsonResponse({'error':'Backup conflict. Export local data, then restore the server backup before syncing again.'},status=409)
            row.snapshot=snapshot;row.revision+=1;row.last_request=request_id;row.save()
            return JsonResponse({'revision':row.revision})
    except (ValueError,UnicodeDecodeError,ValidationError) as exc:
        return JsonResponse({'error':str(exc) if isinstance(exc,BadInput) else 'Invalid request.'},status=400)
