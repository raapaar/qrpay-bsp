import os
from pathlib import Path
from urllib.parse import urlparse, unquote
BASE_DIR = Path(__file__).resolve().parent.parent
DEBUG = os.environ.get('DEBUG', '0') == '1'
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', '')
if not SECRET_KEY:
    if not DEBUG:
        raise RuntimeError('Set DJANGO_SECRET_KEY. Use DEBUG=1 only for local testing.')
    SECRET_KEY = 'local-development-only-not-for-deployment'
ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1,testserver').split(',')
ROOT_URLCONF = 'qrpay.urls'
INSTALLED_APPS = ['django.contrib.auth', 'django.contrib.contenttypes', 'qrpay']
MIDDLEWARE = ['django.middleware.security.SecurityMiddleware', 'django.middleware.common.CommonMiddleware']
USE_TZ = True
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator', 'OPTIONS': {'min_length': 12}},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]
DATABASES = {'default': {'ENGINE': 'django.db.backends.sqlite3', 'NAME': BASE_DIR / 'db.sqlite3'}}
if os.environ.get('DATABASE_URL'):
    u = urlparse(os.environ['DATABASE_URL'])
    DATABASES = {'default': {'ENGINE': 'django.db.backends.postgresql', 'NAME': u.path.lstrip('/'),
        'USER': unquote(u.username or ''), 'PASSWORD': unquote(u.password or ''),
        'HOST': u.hostname, 'PORT': u.port or 5432, 'CONN_MAX_AGE': 60}}
DATA_UPLOAD_MAX_MEMORY_SIZE = 4 * 1024 * 1024
SECURE_SSL_REDIRECT = not DEBUG
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SECURE_CONTENT_TYPE_NOSNIFF = True
# Deploy only behind a trusted reverse proxy that replaces X-Forwarded-Proto.
