import 'package:bantay_baha/domain/models/advisory.dart';
import 'package:bantay_baha/domain/models/flood.dart';
import 'package:bantay_baha/domain/models/telemetry.dart';

abstract interface class FloodRepository {

  Future<Flood?> getFloodLive({Map<String, dynamic>? queryParameters, Map<String, String>? headers});
  Future<Telemetry?> getTelemetry({Map<String, dynamic>? queryParameters});
  Future<List<Advisory>?> getAdvisories({Map<String, dynamic>? queryParameters, Map<String, String>? headers});
}