import json
from django.test import TestCase, override_settings
from django.contrib.auth import get_user_model
from .models import Backup, AccessToken
from .views import issue_token

@override_settings(SECURE_SSL_REDIRECT=False)
class BackupTests(TestCase):
    def setUp(self):
        self.user=get_user_model().objects.create_user('tester',password='local-test-passphrase-99')
        self.token=issue_token(self.user)['token']
    def call(self,action,data=None,token=None):
        return self.client.post('/api/'+action,json.dumps(data or {}),content_type='application/json',
            HTTP_AUTHORIZATION='Bearer '+(token or self.token))
    def test_rejects_anonymous_backup(self):
        self.assertEqual(self.call('restore',token='invalid').status_code,401)
    def test_backup_is_private_idempotent_and_rejects_stale_revision(self):
        data={'revision':0,'requestId':'one','snapshot':{'displayName':'Tester'}}
        self.assertEqual(self.call('sync',data).json()['revision'],1)
        self.assertEqual(self.call('sync',data).json()['revision'],1)
        self.assertEqual(self.call('sync',{**data,'requestId':'two'}).status_code,409)
        other=get_user_model().objects.create_user('other')
        token=issue_token(other)['token']
        self.assertEqual(self.call('restore',token=token).json()['snapshot'],{})
        self.assertEqual(self.call('restore').json()['snapshot'],{'displayName':'Tester'})
    def test_rejects_secret_fields_and_fabricated_live_records(self):
        for snapshot in [{'pin':'1234'}, {'activity':[{'id':'a','demo':False,'kind':'pay', 'status':'demoSuccess','amountMinor':100}]}]:
            self.assertEqual(self.call('sync',{'revision':0,'requestId':'a','snapshot':snapshot}).status_code,400)
        self.assertEqual(Backup.objects.count(),0)
    def test_only_strong_password_can_register_and_token_is_hashed(self):
        self.assertEqual(self.call('register',{'username':'new','password':'123'}).status_code,400)
        response=self.call('register',{'username':'new','password':'Different-strong-passphrase-01'})
        self.assertEqual(response.status_code,200)
        self.assertFalse(AccessToken.objects.filter(digest=response.json()['token']).exists())
    def test_account_deletion_removes_backup_and_tokens(self):
        self.call('sync',{'revision':0,'requestId':'one','snapshot':{}})
        self.assertEqual(self.call('delete-account').status_code,200)
        self.assertFalse(Backup.objects.exists())
        self.assertFalse(AccessToken.objects.exists())
        self.assertFalse(get_user_model().objects.filter(pk=self.user.pk).exists())
    def test_demo_data_never_enters_percentiles(self):
        self.assertFalse(self.call('insights').json()['eligible'])
        self.assertEqual(self.call('payment').status_code,404)
