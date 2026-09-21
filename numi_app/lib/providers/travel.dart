import '../data/repositories/trip_plan_repository.dart';
import '../models/trip_plan.dart';
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

final tripPlanRepositoryProvider = Provider<TripPlanRepository>((ref) =>
    TripPlanRepository(
        ref.watch(databaseProvider), ref.watch(travelApiProvider),
        prepareTrip: ref.watch(travelRepositoryProvider).flushTrips));
final tripPlanProvider = StreamProvider.family<TripPlan, int>(
    (ref, id) => ref.watch(tripPlanRepositoryProvider).watch(id));
