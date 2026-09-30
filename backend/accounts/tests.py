from datetime import date
from unittest.mock import patch

from django.test import TestCase

from core.models import ExchangeRate
from .models import Account, BalanceSnapshot


class NetWorthTrendTests(TestCase):
    def snapshot(self, account, day, usd, sgd=None):
        return BalanceSnapshot.objects.create(
            account=account, snapshot_date=date(2026, 9, day),
            balance=usd, amount_usd=usd,
            amount_sgd=sgd if sgd is not None else usd * 1.3,
        )

    def test_latest_daily_balance_carries_forward_and_excludes_accounts(self):
        bank = Account.objects.create(name='Bank', currency='USD')
        broker = Account.objects.create(name='Broker', currency='USD')
        excluded = Account.objects.create(
            name='Excluded', currency='USD', include_in_total=False,
        )
        self.snapshot(bank, 1, 100)
        self.snapshot(bank, 1, 120)
        self.snapshot(broker, 1, 50)
        self.snapshot(excluded, 2, 9000)
        self.snapshot(broker, 3, 70)
        self.snapshot(bank, 5, -10)
        data = self.client.get('/assets/api/trend/?currency=USD').json()
        self.assertEqual(data['dates'], ['2026-09-01', '2026-09-03', '2026-09-05'])
        self.assertEqual(data['values'], [170, 190, 60])

    @patch('accounts.views.get_rates')
    def test_jpy_uses_each_snapshots_historical_rate(self, get_rates):
        bank = Account.objects.create(name='Bank', currency='USD')
        broker = Account.objects.create(name='Broker', currency='USD')
        for day, rate in [(1, 140), (3, 150)]:
            ExchangeRate.objects.create(
                rate_date=date(2026, 9, day), cny=7, hkd=7.8, sgd=1.3, jpy=rate,
            )
        self.snapshot(bank, 1, 100)
        self.snapshot(broker, 3, 50)
        with self.assertNumQueries(3):
            data = self.client.get('/assets/api/trend/?currency=JPY').json()
        self.assertEqual(data['values'], [14000, 21500])
        get_rates.assert_not_called()

    @patch('accounts.views.get_rates', return_value={'jpy': 150})
    def test_jpy_missing_cache_fetches_historical_date_once(self, get_rates):
        bank = Account.objects.create(name='Bank', currency='USD')
        self.snapshot(bank, 1, 100)
        self.snapshot(bank, 1, 110)
        data = self.client.get('/assets/api/trend/?currency=JPY').json()
        self.assertEqual(data['values'], [16500])
        get_rates.assert_called_once_with('2026-09-01')

    @patch('accounts.views.get_rates', return_value={'jpy': 150})
    def test_native_jpy_balance_preserves_precision(self, get_rates):
        bank = Account.objects.create(name='Yen', currency='JPY')
        snapshot = self.snapshot(bank, 1, 0.67)
        snapshot.balance = 101
        snapshot.save()
        data = self.client.get('/assets/api/trend/?currency=JPY').json()
        self.assertEqual(data['values'], [101])

    def test_empty_and_invalid_currency(self):
        self.assertEqual(
            self.client.get('/assets/api/trend/?currency=invalid').json(),
            {'currency': 'SGD', 'dates': [], 'values': []},
        )
