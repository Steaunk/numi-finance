from django.urls import path

from . import views

urlpatterns = [
    path('', views.index, name='expenses_index'),
    path('api/expenses/', views.list_expenses, name='list_expenses'),
    path('api/expenses/add/', views.add_expense, name='add_expense'),
    path('api/expenses/bulk/', views.bulk_add_expenses, name='bulk_add_expenses'),
    path('api/expenses/<int:expense_id>/', views.delete_expense, name='delete_expense'),
    path('api/categories/', views.list_categories, name='list_categories'),
    path('api/stats/monthly/', views.monthly_stats, name='monthly_stats'),
]
