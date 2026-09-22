from django.db import migrations


def backfill_destinations(apps, schema_editor):
    Trip = apps.get_model('expenses', 'Trip')
    TripPlan = apps.get_model('expenses', 'TripPlan')
    TravelExpense = apps.get_model('expenses', 'TravelExpense')
    for trip in Trip.objects.all().iterator():
        plan = TripPlan.objects.filter(trip_id=trip.pk).first()
        if plan is None and trip.destination.strip():
            # The original destination is the only known geography. Preserve it
            # as a whole-trip visit; payment dates cannot identify individual cities.
            destination_id = f'legacy-trip-{trip.pk}'
            TripPlan.objects.create(
                trip_id=trip.pk,
                revision=1,
                mutation_id=f'destination-migration-{trip.pk}',
                content={'items': [{
                    'id': destination_id,
                    'kind': 'destination',
                    'title': trip.destination,
                    'category': 'Destination',
                    'status': 'planned',
                    'date': trip.start_date.isoformat(),
                    'endDate': trip.end_date.isoformat(),
                    'links': [],
                }]},
            )
            TravelExpense.objects.filter(
                trip_id=trip.pk, plan_item_id__isnull=True, destination_id='',
            ).update(destination_id=destination_id)
            continue
        if plan is None:
            continue
        items = {item['id']: item for item in plan.content.get('items', [])}
        destinations = {key for key, item in items.items() if item['kind'] == 'destination'}
        for expense in TravelExpense.objects.filter(trip_id=trip.pk, plan_item_id__isnull=False):
            item = items.get(expense.plan_item_id, {})
            source = items.get(item['placeId'], {}) if item.get('placeId') else item
            destination_id = source.get('destinationId', '')
            if destination_id in destinations:
                TravelExpense.objects.filter(pk=expense.pk).update(destination_id=destination_id)


class Migration(migrations.Migration):
    dependencies = [('expenses', '0008_travelexpense_destination_id')]
    operations = [migrations.RunPython(backfill_destinations, migrations.RunPython.noop)]
