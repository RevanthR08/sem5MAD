import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _baseUrl = ApiConstants.baseUrl;

  Future<List<Category>> getCategories() async {
    final response = await http.get(Uri.parse('$_baseUrl/categories'));
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => Category.fromJson(item)).toList();
    }
    throw Exception('Failed to load categories');
  }

  Future<List<CivicReport>> getReports({
    String? status,
    String? categoryId,
    String? priority,
    String? search,
  }) async {
    final queryParams = <String, String>{};
    if (status != null && status != 'ALL') queryParams['status'] = status;
    if (categoryId != null && categoryId != 'ALL') queryParams['category_id'] = categoryId;
    if (priority != null && priority != 'ALL') queryParams['priority'] = priority;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$_baseUrl/reports').replace(queryParameters: queryParams);
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => CivicReport.fromJson(item)).toList();
    }
    throw Exception('Failed to load reports');
  }

  Future<CivicReport> getReportDetail(String idOrPublicId) async {
    final response = await http.get(Uri.parse('$_baseUrl/reports/$idOrPublicId'));
    if (response.statusCode == 200) {
      return CivicReport.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load report detail');
  }

  Future<List<DuplicateReportItem>> checkDuplicates(double lat, double lng, String categoryId) async {
    final uri = Uri.parse('$_baseUrl/reports/duplicates?lat=$lat&lng=$lng&category_id=$categoryId');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> list = data['duplicates'] ?? [];
      return list.map((item) => DuplicateReportItem.fromJson(item)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse('$_baseUrl/locations/reverse-geocode?lat=$lat&lng=$lng');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {
      'address': '$lat, $lng, Chennai',
      'city': 'Chennai',
      'ward_name': 'Ward 123 (Mylapore)'
    };
  }

  Future<Map<String, dynamic>> createReport(Map<String, dynamic> reportData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/reports'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(reportData),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create report: ${response.body}');
  }

  Future<void> updateReportStatus(String reportId, Map<String, dynamic> updateData) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/reports/$reportId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(updateData),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update status');
    }
  }

  Future<void> assignReport(String reportId, String teamName, String workerId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/reports/$reportId/assign'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'assigned_team': teamName,
        'assigned_to': workerId,
        'notes': 'Dispatched team: $teamName',
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to assign report');
    }
  }

  Future<void> resolveReport({
    required String reportId,
    required String resolutionNotes,
    String? beforePhoto,
    String? afterPhoto,
    String workerName = 'Murugan S (Field Worker)',
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/reports/$reportId/resolve'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'actor_name': workerName,
        'resolution_notes': resolutionNotes,
        'before_photo': beforePhoto,
        'after_photo': afterPhoto,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to resolve report');
    }
  }

  Future<void> verifyReport({
    required String reportId,
    required bool isFixed,
    String? feedback,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/reports/$reportId/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'is_fixed': isFixed,
        'feedback': feedback,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to verify report');
    }
  }

  Future<String> uploadImage(String base64Data, {String filename = 'photo.jpg'}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/reports/upload-image'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'base64_data': base64Data,
        'filename': filename,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['url'] as String;
    }
    throw Exception('Failed to upload image to Supabase');
  }

  Future<int> upvoteReport(String reportId) async {
    final response = await http.post(Uri.parse('$_baseUrl/reports/$reportId/upvote'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['upvotes'] ?? 1;
    }
    return 1;
  }

  Future<AnalyticsOverview> getAnalyticsOverview() async {
    final response = await http.get(Uri.parse('$_baseUrl/analytics/overview'));
    if (response.statusCode == 200) {
      return AnalyticsOverview.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load analytics');
  }
}
