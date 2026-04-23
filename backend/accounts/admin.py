from django.contrib import admin

from .models import Account, BalanceSnapshot


@admin.register(Account)
class AccountAdmin(admin.ModelAdmin):
    list_display = ('name', 'currency', 'balance', 'include_in_total', 'updated_at')
    list_filter = ('currency', 'include_in_total')
    search_fields = ('name',)


class BalanceSnapshotInline(admin.TabularInline):
    model = BalanceSnapshot
    extra = 0
    fields = ('snapshot_date', 'balance', 'change', 'amount_usd', 'amount_cny', 'amount_hkd', 'amount_sgd')
    readonly_fields = ('amount_usd', 'amount_cny', 'amount_hkd', 'amount_sgd')
    ordering = ('-snapshot_date',)


AccountAdmin.inlines = [BalanceSnapshotInline]


@admin.register(BalanceSnapshot)
class BalanceSnapshotAdmin(admin.ModelAdmin):
    list_display = ('snapshot_date', 'account', 'balance', 'change', 'amount_usd', 'amount_sgd')
    list_filter = ('snapshot_date', 'account')
    ordering = ('-snapshot_date',)
