from django.urls import path

from . import views

urlpatterns = [
    path('rates/latest/', views.latest_rates, name='latest_rates'),
    path('geo/currency/', views.detect_currency, name='detect_currency'),
]
