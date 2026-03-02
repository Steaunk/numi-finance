"""Remove ExchangeRate from expenses app state (table stays for core to pick up)."""

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('expenses', '0001_initial'),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            state_operations=[
                migrations.DeleteModel(
                    name='ExchangeRate',
                ),
            ],
            database_operations=[],
        ),
    ]
