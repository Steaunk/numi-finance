import logging

from django.core.management.base import BaseCommand

from assets.models import Account
from assets.views import _do_sync_api_accounts

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Sync API-connected accounts and create daily balance snapshots.'

    def handle(self, *args, **options):
        accounts = list(
            Account.objects.exclude(api_url__isnull=True).exclude(api_url='')
        )
        if not accounts:
            self.stdout.write('No API accounts to sync.')
            return

        results = _do_sync_api_accounts(accounts, create_snapshot=True)
        for r in results:
            if 'error' in r:
                logger.warning('Sync %s (%s): %s', r['name'], r['id'], r['error'])
                self.stdout.write(self.style.WARNING(f"  {r['name']}: {r['error']}"))
            else:
                logger.info('Sync %s (%s): balance=%.2f change=%.2f',
                            r['name'], r['id'], r['balance'], r['change'])
                self.stdout.write(self.style.SUCCESS(
                    f"  {r['name']}: {r['balance']:.2f} (change: {r['change']:+.2f})"
                ))

        self.stdout.write(f'Synced {len(results)} account(s).')
