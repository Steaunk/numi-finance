from django.db import models

CURRENCY_CHOICES = [
    ('CNY', 'CNY'),
    ('HKD', 'HKD'),
    ('USD', 'USD'),
    ('SGD', 'SGD'),
    ('JPY', 'JPY'),
]

VALID_CURRENCIES = {c[0] for c in CURRENCY_CHOICES}


class ExchangeRate(models.Model):
    rate_date = models.DateField(unique=True)
    fetched_at = models.DateTimeField(auto_now_add=True)
    cny = models.FloatField()
    hkd = models.FloatField()
    sgd = models.FloatField()
    jpy = models.FloatField(default=150.0)

    class Meta:
        ordering = ['-rate_date']

    def __str__(self):
        return f"Rates for {self.rate_date}"
