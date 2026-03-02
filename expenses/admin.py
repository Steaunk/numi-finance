from django.contrib import admin

from .models import Expense, Trip, TravelExpense


@admin.register(Expense)
class ExpenseAdmin(admin.ModelAdmin):
    list_display = ('date', 'name', 'amount', 'currency', 'category', 'amount_usd', 'amount_sgd')
    list_filter = ('currency', 'category', 'date')
    search_fields = ('name', 'notes')
    ordering = ('-date',)


@admin.register(Trip)
class TripAdmin(admin.ModelAdmin):
    list_display = ('destination', 'start_date', 'end_date', 'notes')
    ordering = ('-start_date',)


class TravelExpenseInline(admin.TabularInline):
    model = TravelExpense
    extra = 0
    fields = ('date', 'name', 'amount', 'currency', 'category', 'amount_usd', 'amount_sgd')
    readonly_fields = ('amount_usd', 'amount_cny', 'amount_hkd', 'amount_sgd')


# Also add inline to Trip
TripAdmin.inlines = [TravelExpenseInline]


@admin.register(TravelExpense)
class TravelExpenseAdmin(admin.ModelAdmin):
    list_display = ('date', 'name', 'amount', 'currency', 'category', 'trip', 'amount_usd', 'amount_sgd')
    list_filter = ('currency', 'category', 'trip')
    search_fields = ('name', 'notes')
    ordering = ('-date',)
