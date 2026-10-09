import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trip.dart' as model;
import 'core.dart';
import '../data/repositories/trip_plan_repository.dart';

final tripListProvider = StreamProvider<List<model.Trip>>((ref) {
  return ref.watch(travelRepositoryProvider).watchAllTrips();
});

final tripDetailProvider =
    StreamProvider.family<model.Trip?, int>((ref, tripId) {
  return ref.watch(travelRepositoryProvider).watchTripWithExpenses(tripId);
});

final tripPlanRepositoryProvider = Provider<TripPlanRepository>((ref) =>
    TripPlanRepository(ref.watch(databaseProvider),
        ref.watch(travelApiProvider), ref.watch(travelRepositoryProvider)));
final tripPlanProvider = StreamProvider.family<PlanState, int>(
    (ref, id) => ref.watch(tripPlanRepositoryProvider).watch(id));
