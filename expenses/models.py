from django.db import models


class ExchangeRate(models.Model):
    rate_date = models.DateField(unique=True)
    fetched_at = models.DateTimeField(auto_now_add=True)
    cny = models.FloatField()
    hkd = models.FloatField()
    sgd = models.FloatField()

    class Meta:
        ordering = ['-rate_date']

    def __str__(self):
        return f"Rates for {self.rate_date}"


class Expense(models.Model):
    CURRENCY_CHOICES = [
        ('CNY', 'CNY'),
        ('HKD', 'HKD'),
        ('USD', 'USD'),
        ('SGD', 'SGD'),
    ]

    amount = models.FloatField()
    currency = models.CharField(max_length=3, choices=CURRENCY_CHOICES)
    date = models.DateField()
    category = models.CharField(max_length=50)
    name = models.CharField(max_length=100)
    notes = models.TextField(blank=True, default='')
    rate_cny = models.FloatField()
    rate_hkd = models.FloatField()
    rate_sgd = models.FloatField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date', '-created_at']

    def __str__(self):
        return f"{self.name} - {self.amount} {self.currency} ({self.date})"
