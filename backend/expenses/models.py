import uuid
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
    destination_id = models.CharField(max_length=64, blank=True, default='')
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
    """Versioned shared travel plan; expenses remain private."""
    trip = models.OneToOneField(Trip, on_delete=models.CASCADE, related_name='plan')
    content = models.JSONField(default=dict)
    revision = models.PositiveIntegerField(default=0)
    mutation_id = models.CharField(max_length=64, blank=True, default='')
    updated_at = models.DateTimeField(auto_now=True)


class TripPlanChange(models.Model):
    trip = models.ForeignKey(Trip, on_delete=models.CASCADE, related_name='plan_changes')
    revision = models.PositiveIntegerField()
    content = models.JSONField()
    actor = models.CharField(max_length=100, default='Owner')
    mutation_id = models.CharField(max_length=64, blank=True)
    request_hash = models.CharField(max_length=64, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=['trip', 'revision'], name='unique_trip_plan_revision')]
        ordering = ['-revision']


class TripInvite(models.Model):
    trip = models.ForeignKey(Trip, on_delete=models.CASCADE, related_name='invites')
    token_hash = models.CharField(max_length=64, unique=True)
    name = models.CharField(max_length=100)
    person_id = models.CharField(max_length=64, blank=True)
    role = models.CharField(max_length=10, choices=[('viewer', 'Viewer'), ('editor', 'Editor')])
    expires_at = models.DateTimeField()
    revoked_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)


class TravelDocument(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    trip = models.ForeignKey(Trip, on_delete=models.CASCADE, related_name='documents')
    name = models.CharField(max_length=200)
    sha256 = models.CharField(max_length=64)
    size = models.PositiveIntegerField()
    data = models.BinaryField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=['trip', 'sha256'], name='unique_trip_document_hash')]
