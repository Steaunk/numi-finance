from django.db import models

from core.models import CURRENCY_CHOICES


class Account(models.Model):
    name = models.CharField(max_length=100)
    currency = models.CharField(max_length=3, choices=CURRENCY_CHOICES)
    balance = models.FloatField(default=0)
    include_in_total = models.BooleanField(default=True)
    notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return f"{self.name} ({self.currency})"


class BalanceSnapshot(models.Model):
    account = models.ForeignKey(Account, on_delete=models.CASCADE, related_name='snapshots')
    balance = models.FloatField()
    change = models.FloatField(default=0)
    snapshot_date = models.DateField()
    amount_usd = models.FloatField(default=0)
    amount_cny = models.FloatField(default=0)
    amount_hkd = models.FloatField(default=0)
    amount_sgd = models.FloatField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-snapshot_date', '-created_at']

    def __str__(self):
        return f"{self.account.name}: {self.balance} on {self.snapshot_date}"
