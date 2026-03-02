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

    # Travel
    path('travel/', views.travel_index, name='travel_index'),
    path('api/travel/trips/', views.list_trips, name='list_trips'),
    path('api/travel/trips/add/', views.add_trip, name='add_trip'),
    path('api/travel/trips/<int:trip_id>/', views.update_trip, name='update_trip'),
    path('api/travel/trips/<int:trip_id>/delete/', views.delete_trip, name='delete_trip'),
    path('api/travel/trips/<int:trip_id>/expenses/', views.list_trip_expenses, name='list_trip_expenses'),
    path('api/travel/trips/<int:trip_id>/expenses/add/', views.add_trip_expense, name='add_trip_expense'),
    path('api/travel/trips/<int:trip_id>/expenses/<int:expense_id>/delete/', views.delete_trip_expense, name='delete_trip_expense'),
]
