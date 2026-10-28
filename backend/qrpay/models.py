from django.conf import settings
from django.db import models

class Backup(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    revision = models.PositiveIntegerField(default=0)
    snapshot = models.JSONField(default=dict)
    last_request = models.CharField(max_length=100, blank=True)

class AccessToken(models.Model):
    digest = models.CharField(max_length=64, unique=True)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    expires = models.DateTimeField()

class RateLimit(models.Model):
    key = models.CharField(max_length=64, primary_key=True)
    started = models.DateTimeField()
    count = models.PositiveIntegerField(default=0)
