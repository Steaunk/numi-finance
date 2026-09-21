from django.db import models
import uuid

def expense_client_id():
    return uuid.uuid4().hex


EXPENSE_CATEGORIES = [
    'Bills, Utilities & Taxes',
    'Education',
    'Entertainment',
    'Food & Drinks',
    'Groceries',
    'Health & Fitness',
    'Housing',
    'Others',
    'Transport',
    'Travel',
]


class Expense(models.Model):
    amount = models.FloatField()
    currency = models.CharField(max_length=3)
    date = models.DateField()
    category = models.CharField(max_length=50)
    name = models.CharField(max_length=100)
    notes = models.TextField(blank=True, default='')
    amount_usd = models.FloatField(default=0)
    amount_cny = models.FloatField(default=0)
    amount_hkd = models.FloatField(default=0)
    amount_sgd = models.FloatField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date', '-created_at']

    def __str__(self):
        return f"{self.name} - {self.amount} {self.currency} ({self.date})"


TRAVEL_CATEGORIES = [
    'Transportation',
    'Accommodation',
    'Sightseeing',
    'Food & Drinks',
    'Shopping',
    'Other',
]


class Trip(models.Model):
    client_id = models.CharField(max_length=64, unique=True, null=True, blank=True)
    destination = models.CharField(max_length=200)
    start_date = models.DateField()
    end_date = models.DateField()
    notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-start_date', '-created_at']

    def __str__(self):
        return f"{self.destination} ({self.start_date} ~ {self.end_date})"


class TravelExpense(models.Model):
    client_id = models.CharField(max_length=64, unique=True, default=expense_client_id)
    plan_item_id = models.CharField(max_length=64, null=True, blank=True)
    trip = models.ForeignKey(Trip, on_delete=models.CASCADE, related_name='expenses')
    amount = models.FloatField()
    currency = models.CharField(max_length=3)
    date = models.DateField()
    category = models.CharField(max_length=50)
    name = models.CharField(max_length=500)
    notes = models.TextField(blank=True, default='')
    amount_usd = models.FloatField(default=0)
    amount_cny = models.FloatField(default=0)
    amount_hkd = models.FloatField(default=0)
    amount_sgd = models.FloatField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date', '-created_at']

    def __str__(self):
        return f"{self.name} - {self.amount} {self.currency}"


class TripPlan(models.Model):
    """Versioned single-traveller planning document; expenses remain separate."""
    trip = models.OneToOneField(Trip, on_delete=models.CASCADE, related_name='plan')
    content = models.JSONField(default=dict)
    revision = models.PositiveIntegerField(default=0)
    mutation_id = models.CharField(max_length=64, blank=True, default='')
    updated_at = models.DateTimeField(auto_now=True)
