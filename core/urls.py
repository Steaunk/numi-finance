from django.urls import path

from . import views

urlpatterns = [
    path('rates/', views.rates, name='rates'),
    path('geo/currency/', views.detect_currency, name='detect_currency'),
]
