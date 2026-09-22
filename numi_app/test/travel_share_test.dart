import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numi_app/models/travel_share.dart';
import 'package:numi_app/models/trip_plan.dart';
import 'package:numi_app/utils/travel_share_receiver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('imported search dates require review and never record a payment', () {
    final draft = TravelShareDraft({
      'title': 'Ocean house',
      'category': 'Accommodation',
      'date': '2026-10-07',
      'endDate': '2026-10-09',
      'amount': '999',
      'paymentStatus': 'paid',
      'links': [
        {'url': 'https://www.airbnb.com/rooms/123', 'purpose': 'Booking'}
      ],
    });
    final booking = draft.item('booking');
    expect(booking['status'], 'planned');
    expect(booking['date'], '2026-10-07');
    expect(booking['amount'], '');
    expect(booking['paymentStatus'], isNot('paid'));
    expect(booking.participantIds, isEmpty);
    final place = draft.item('place');
    expect(place['category'], 'Accommodation');
    expect(place['date'], '');
  });
  test('flight and activity drafts keep the supplied segment details', () {
    final flight = TravelShareDraft({
      'kind': 'booking',
      'category': 'Flight',
      'title': 'SQ638',
      'address': 'SIN',
      'endAddress': 'NRT',
      'date': '2026-10-06',
      'endDate': '2026-10-07',
      'time': '23:55',
      'endTime': '07:30',
      'timezone': 'UTC+08:00',
      'endTimezone': 'UTC+09:00'
    });
    expect(flight.suggestedKind, 'booking');
    final item = flight.item('booking');
    expect(item['category'], 'Flight');
    expect(item['endAddress'], 'NRT');
    expect(item['time'], '23:55');
    expect(item['endTimezone'], 'UTC+09:00');
    final activity = TravelShareDraft({
      'kind': 'activity',
      'title': 'YAYOI KUSAMA MUSEUM',
      'date': '2026-10-10',
      'time': '11:00'
    });
    expect(activity.suggestedKind, 'activity');
    expect(activity.item('activity')['time'], '11:00');
  });
  test('offline import retains original text and URL', () {
    const url = 'https://abnb.me/abc';
    final draft = TravelShareDraft.offline('Ocean house\n$url', url);
    expect(draft.source, 'Airbnb');
    expect(draft.warning, isNotEmpty);
    expect(draft.item('place')['notes'], 'Ocean house\n$url');
    expect(draft.item('place').links.single.url, url);
    expect(linkPlatform('https://g.co/kgs/xyz'), 'Google Maps');
  });
  test('PDF shares keep the native original until review is dismissed',
      () async {
    const channel = MethodChannel('numi/pdf_share_test');
    final next = <String, dynamic>{
      'id': 'pdf-one',
      'type': 'pdf',
      'path': '/private/ticket.pdf',
      'name': 'Ticket.pdf'
    };
    final done = Completer<void>();
    bool acknowledged = false;
    Map<String, dynamic>? document;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'peek') return acknowledged ? null : next;
      if (call.method == 'acknowledge') acknowledged = true;
      return null;
    });
    final receiver = TravelShareReceiver(
        (text) async => fail('PDF was treated as text'),
        channel: channel, openDocument: (pdf) {
      document = pdf;
      return done.future;
    });
    final running = receiver.start();
    await Future<void>.delayed(Duration.zero);
    expect(document?['path'], '/private/ticket.pdf');
    expect(acknowledged, isFalse);
    done.complete();
    await running;
    expect(acknowledged, isTrue);
    receiver.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });
  test('cold and warm shares serialize and are acknowledged after review',
      () async {
    const channel = MethodChannel('numi/travel_share_test');
    final queue = [
      <String, dynamic>{'id': 'one', 'text': 'first'}
    ];
    final opened = <String>[];
    final reviews = <Completer<void>>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'peek') return queue.isEmpty ? null : queue.first;
      if (call.method == 'acknowledge') {
        queue.removeWhere((r) => r['id'] == call.arguments);
      }
      return null;
    });
    final receiver = TravelShareReceiver((text) {
      opened.add(text);
      final review = Completer<void>();
      reviews.add(review);
      return review.future;
    }, channel: channel);
    final running = receiver.start();
    await Future<void>.delayed(Duration.zero);
    expect(opened, ['first']);
    expect(queue, hasLength(1));
    queue.add({'id': 'two', 'text': 'second'});
    await receiver.drain();
    expect(opened, ['first']);
    reviews.first.complete();
    await Future<void>.delayed(Duration.zero);
    expect(opened, ['first', 'second']);
    expect(queue.single['id'], 'two');
    reviews.last.complete();
    await running;
    expect(queue, isEmpty);
    await receiver.drain();
    expect(opened, hasLength(2));
    receiver.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });
}
