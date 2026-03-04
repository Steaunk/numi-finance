from django.urls import path

from . import views

urlpatterns = [
    path('rates/', views.rates, name='rates'),
    path('geo/currency/', views.detect_currency, name='detect_currency'),
    path('account-icons/', views.account_icon_list, name='account_icons'),
]
