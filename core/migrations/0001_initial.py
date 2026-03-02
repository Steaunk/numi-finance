"""Take ownership of ExchangeRate table from expenses app and add JPY field."""

from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('expenses', '0002_remove_exchangerate_from_expenses'),
    ]

    operations = [
        # Create the model in state, pointing to the existing DB table
        migrations.SeparateDatabaseAndState(
            state_operations=[
                migrations.CreateModel(
                    name='ExchangeRate',
                    fields=[
                        ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                        ('rate_date', models.DateField(unique=True)),
                        ('fetched_at', models.DateTimeField(auto_now_add=True)),
                        ('cny', models.FloatField()),
                        ('hkd', models.FloatField()),
                        ('sgd', models.FloatField()),
                    ],
                    options={
                        'ordering': ['-rate_date'],
                    },
                ),
            ],
            database_operations=[
                # Rename the table from expenses_exchangerate to core_exchangerate
                migrations.RunSQL(
                    sql='ALTER TABLE expenses_exchangerate RENAME TO core_exchangerate;',
                    reverse_sql='ALTER TABLE core_exchangerate RENAME TO expenses_exchangerate;',
                ),
            ],
        ),
        # Now add the jpy field
        migrations.AddField(
            model_name='exchangerate',
            name='jpy',
            field=models.FloatField(default=150.0),
        ),
    ]
