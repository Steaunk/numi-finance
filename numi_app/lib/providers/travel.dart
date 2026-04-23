import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trip.dart' as model;
import 'core.dart';

final tripListProvider = StreamProvider<List<model.Trip>>((ref) {
  return ref.watch(travelRepositoryProvider).watchAllTrips();
});

final tripDetailProvider =
    StreamProvider.family<model.Trip?, int>((ref, tripId) {
  return ref.watch(travelRepositoryProvider).watchTripWithExpenses(tripId);
});
