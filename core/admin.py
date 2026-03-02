from django.contrib import admin

from .models import ExchangeRate


@admin.register(ExchangeRate)
class ExchangeRateAdmin(admin.ModelAdmin):
    list_display = ('rate_date', 'cny', 'hkd', 'sgd', 'jpy', 'fetched_at')
    list_filter = ('rate_date',)
    ordering = ('-rate_date',)
