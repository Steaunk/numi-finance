from django.db import migrations, models


MONEY = {'amount', 'currency', 'paymentStatus', 'paidDate', 'expenseClientId', 'expenseCategory'}


def clean(content):
    items = content.get('items', [])
    places = {i['id']: i for i in items if i.get('kind') == 'place'}
    for item in items:
        if item.get('kind') == 'activity' and item.get('category') in ('Activity', '', None):
            category = places.get(item.get('placeId'), {}).get('category') or item.get('expenseCategory', 'Other')
            item['category'] = {'Food & Drinks': 'Restaurant', 'Transportation': 'Practical'}.get(category, category)
        for key in MONEY:
            item.pop(key, None)
    return content


def forward(apps, schema_editor):
    Expense = apps.get_model('expenses', 'TravelExpense')
    Plan = apps.get_model('expenses', 'TripPlan')
    History = apps.get_model('expenses', 'TripPlanChange')
    for expense in Expense.objects.exclude(plan_item_id__isnull=True).iterator():
        expense.plan_item_ids = [expense.plan_item_id] if expense.plan_item_id else []
        expense.plan_item_id = None
        expense.save(update_fields=['plan_item_ids', 'plan_item_id'])
    for history in History.objects.all().iterator():
        history.content = clean(history.content)
        history.save(update_fields=['content'])
    for plan in Plan.objects.all().iterator():
        plan.content = clean(plan.content)
        plan.revision += 1
        plan.mutation_id = ''
        plan.save(update_fields=['content', 'revision', 'mutation_id'])
        History.objects.create(trip_id=plan.trip_id, revision=plan.revision,
                               content=plan.content, actor='Expense links migration')


class Migration(migrations.Migration):
    dependencies = [('expenses', '0011_traveldocument')]
    operations = [
        migrations.AddField(model_name='travelexpense', name='plan_item_ids', field=models.JSONField(default=list, blank=True)),
        migrations.RunPython(forward, migrations.RunPython.noop),
    ]
