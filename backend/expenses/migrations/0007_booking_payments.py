from django.db import migrations, models
import expenses.models


def identities(apps, schema_editor):
    Expense = apps.get_model('expenses', 'TravelExpense')
    for expense in Expense.objects.all().iterator():
        expense.client_id = f'remote-{expense.pk}'
        expense.save(update_fields=['client_id'])


class Migration(migrations.Migration):
    dependencies = [('expenses', '0006_trip_client_id_tripplan')]
    operations = [
        migrations.AddField('travelexpense', 'client_id', models.CharField(max_length=64, null=True)),
        migrations.RunPython(identities, migrations.RunPython.noop),
        migrations.AlterField('travelexpense', 'client_id', models.CharField(max_length=64, unique=True, default=expenses.models.expense_client_id)),
        migrations.AddField('travelexpense', 'plan_item_id', models.CharField(max_length=64, null=True, blank=True)),
        migrations.AlterField('travelexpense', 'name', models.CharField(max_length=500)),
    ]
