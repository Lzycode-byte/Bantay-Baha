import 'package:bantay_baha/ui/home/home_viewmodel.dart';

class MapRouteArgs {
  const MapRouteArgs({required this.model, this.selectedStationId});

  final HomeViewModel model;
  final String? selectedStationId;
}
