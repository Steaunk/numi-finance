from django.urls import path

from . import views

urlpatterns = [
    path('', views.index, name='assets_index'),
    path('api/accounts/', views.list_accounts, name='list_accounts'),
    path('api/accounts/add/', views.add_account, name='add_account'),
    path('api/accounts/<int:account_id>/', views.update_account, name='update_account'),
    path('api/accounts/<int:account_id>/delete/', views.delete_account, name='delete_account'),
    path('api/accounts/<int:account_id>/history/', views.account_history, name='account_history'),
    path('api/net-worth/', views.net_worth, name='net_worth'),
    path('api/trend/', views.trend, name='trend'),
]
