from django.db import models

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
    planner_entry_id = models.CharField(max_length=64, blank=True, default='')
    trip = models.ForeignKey(Trip, on_delete=models.CASCADE, related_name='expenses')
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
        return f"{self.name} - {self.amount} {self.currency}"


class TripPlan(models.Model):
    """One versioned planning document per trip; UUIDs inside stay stable offline."""
    trip = models.OneToOneField(Trip, on_delete=models.CASCADE, related_name='plan')
    document = models.JSONField(default=dict)
    version = models.PositiveIntegerField(default=0)


class TravelMutation(models.Model):
    scope = models.CharField(max_length=64)
    key = models.CharField(max_length=64)
    request_hash = models.CharField(max_length=64)
    response = models.JSONField(default=dict)
    status = models.PositiveSmallIntegerField(default=200)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=['scope', 'key'], name='travel_mutation_unique')]
