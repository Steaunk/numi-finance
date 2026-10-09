from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [('expenses', '0007_booking_payments')]
    operations = [migrations.AddField(
        model_name='travelexpense', name='destination_id',
        field=models.CharField(max_length=64, blank=True, default=''),
    )]
