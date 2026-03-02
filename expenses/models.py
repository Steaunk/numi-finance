from django.db import models

EXPENSE_CURRENCY_CHOICES = [
    ('CNY', 'CNY'),
    ('HKD', 'HKD'),
    ('USD', 'USD'),
    ('SGD', 'SGD'),
]


class Expense(models.Model):
    amount = models.FloatField()
    currency = models.CharField(max_length=3, choices=EXPENSE_CURRENCY_CHOICES)
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
