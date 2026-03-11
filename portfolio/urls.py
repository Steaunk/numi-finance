from django.urls import path

from . import views

urlpatterns = [
    path('api/holdings/', views.holdings, name='portfolio_holdings'),
    path('api/account/', views.account, name='portfolio_account'),
    path('api/history/', views.history, name='portfolio_history'),
    path('api/stock/<str:stock_name>/history/', views.stock_history, name='portfolio_stock_history'),
    path('api/exchange-rates/', views.exchange_rates, name='portfolio_exchange_rates'),
    path('api/broker-values/', views.broker_values, name='portfolio_broker_values'),
    path('api/broker-status/', views.broker_status, name='portfolio_broker_status'),
]
