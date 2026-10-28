# Optional QRpay backup backend

This is a development Django API for app accounts, consented record backup,
feedback drafts, account deletion and update notices. It has no banking endpoint,
no USSD transport and no live payment credentials. No server has been deployed.

## Local development on Windows

From the project root:

```powershell
python -m venv backend\.venv
.\backend\.venv\Scripts\Activate.ps1
pip install -r backend\requirements.txt
$env:DEBUG="1"
python backend\manage.py migrate
python backend\manage.py test qrpay
python backend\manage.py runserver
```

The mobile app requires HTTPS for account credentials. The local HTTP server is
for backend tests only. For phone testing use an owned HTTPS endpoint with a
trusted certificate. Do not disable the client's HTTPS check.

## Deployment configuration

Use Python 3.12 and PostgreSQL for a shared server. Supply DJANGO_SECRET_KEY,
ALLOWED_HOSTS and DATABASE_URL. DEBUG must be 0. The proxy must remove untrusted
X-Forwarded-Proto values before setting its own. Terminate TLS at that trusted
proxy. Run migrations before `gunicorn qrpay.wsgi:application` from backend/.
Do not expose a development runserver. Review operational backups, rate limits,
logging, password recovery and monitoring before opening public registration.
This code has not been exercised on a deployed PostgreSQL service.

## Native API

Every endpoint is POST /api/<action>, Content-Type application/json.
Register/login accept username and an app password (12+ characters); neither is
a bank credential. The returned bearer token expires after 30 days and is stored
hashed on the server. Device tokens use platform secure storage.

- register/login/logout: manage app credentials.
- sync: {revision, requestId, snapshot}; requires a bearer token. Records only.
- restore: retrieves the authenticated user's complete backup.
- delete-account: deletes account, token and backup.
- updates: public version notice, never executable updates.
- insights: reports ineligibility: all current records are demonstrations.

Backups use optimistic revision checks, so a second device or a lost response
cannot silently overwrite a newer backup. A conflict preserves the local copy.
Export local data, restore the server backup, and reconcile manually. Automatic
merging is not implemented. Restore intentionally replaces selected local data
after confirmation. SIM labels are preferences, never proof of registration.

Each sync request can contain at most 2000 entries per collection and 4 MiB total.
Feedback is included only with explicit cloud backup consent. There is no email
or messaging service; feedback resides in the authenticated user's backup.
