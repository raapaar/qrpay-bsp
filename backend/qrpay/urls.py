from django.urls import path
from .views import api
urlpatterns = [path('api/<str:action>', api)]
