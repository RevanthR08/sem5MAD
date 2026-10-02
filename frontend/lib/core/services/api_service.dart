import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _baseUrl = ApiConstants.baseUrl;

  // Identity of the signed-in user, sent with every request so the backend
  // can enforce role permissions and record who acted in the timeline.
  String? _userId;
  String? _role;
  String? _name;

  void setActor({String? userId, required String role, required String name}) {
    _userId = userId;
    _role = role;
    _name = name;
  }

  void clearActor() {
    _userId = null;
    _role = null;
    _name = null;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-User-Role': ?_role,
        'X-User-Id': ?_userId,
        // Header values must be ASCII; the backend decodes this
        if (_name != null) 'X-User-Name': Uri.encodeComponent(_name!),
      };

  /// Extract the backend's `detail` message so the UI can show why a call failed.
  Exception _error(http.Response response, String fallback) {
    try {
      final detail = jsonDecode(response.body)['detail'];
      if (detail is String) return Exception(detail);
    } catch (_) {}
    return Exception('$fallback (HTTP ${response.statusCode})');
  }

  /// GET with one automatic retry when the backend briefly can't reach the
  /// database (503) or the request fails to connect.
  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) async {
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode != 503) return response;
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 600));
    return http.get(uri, headers: headers);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, String fallback) async {
    final response = await http.post(Uri.parse('$_baseUrl$path'), headers: _headers, body: jsonEncode(body));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw _error(response, fallback);
  }

  /// Returns the user map ({id, full_name, role, department_name, ...}).
  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _post('/auth/login', {'email': email, 'password': password}, 'Sign in failed');
    return data['user'];
  }

  /// [role] is CITIZEN, OFFICER or FIELD_WORKER; staff must pass [departmentId].
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? phone,
    String? departmentId,
  }) async {
    final data = await _post('/auth/register', {
      'full_name': fullName,
      'email': email,
      'password': password,
      'role': role,
      'phone': phone,
      'department_id': departmentId,
    }, 'Registration failed');
    return data['user'];
  }

  /// Signed-in user's profile: {user: {...}, stats: {...}, member_since}.
  Future<Map<String, dynamic>> getProfile() async {
    final response = await _get(Uri.parse('$_baseUrl/auth/me'), headers: _headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw _error(response, 'Failed to load profile');
  }

  Future<Map<String, dynamic>> updateProfile({required String fullName, String? phone}) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/auth/me'),
      headers: _headers,
      body: jsonEncode({'full_name': fullName, 'phone': phone}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body)['user'];
    throw _error(response, 'Failed to update profile');
  }

  Future<void> changePassword(String currentPassword, String newPassword) => _post(
      '/auth/me/password', {'current_password': currentPassword, 'new_password': newPassword}, 'Failed to change password');

  /// Field worker demo helper: creates a realistic task assigned to the caller.
  Future<Map<String, dynamic>> createDemoFieldTask() =>
      _post('/reports/demo/field-task', {}, 'Could not create a demo task');

  Future<List<Category>> getCategories() async {
    final response = await _get(Uri.parse('$_baseUrl/categories'), headers: _headers);
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => Category.fromJson(item)).toList();
    }
    throw _error(response, 'Failed to load categories');
  }

  /// [status] may be a single status or a comma-separated list.
  Future<List<CivicReport>> getReports({
    String? status,
    String? categoryId,
    String? priority,
    String? search,
    String? assignedTo,
    String? userId,
  }) async {
    final queryParams = <String, String>{};
    if (status != null && status != 'ALL') queryParams['status'] = status;
    if (categoryId != null && categoryId != 'ALL') queryParams['category_id'] = categoryId;
    if (priority != null && priority != 'ALL') queryParams['priority'] = priority;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (assignedTo != null) queryParams['assigned_to'] = assignedTo;
    if (userId != null) queryParams['user_id'] = userId;

    final uri = Uri.parse('$_baseUrl/reports').replace(queryParameters: queryParams);
    final response = await _get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => CivicReport.fromJson(item)).toList();
    }
    throw _error(response, 'Failed to load reports');
  }

  Future<CivicReport> getReportDetail(String idOrPublicId) async {
    final response = await _get(Uri.parse('$_baseUrl/reports/$idOrPublicId'), headers: _headers);
    if (response.statusCode == 200) {
      return CivicReport.fromJson(jsonDecode(response.body));
    }
    throw _error(response, 'Failed to load report detail');
  }

  Future<List<DuplicateReportItem>> checkDuplicates(double lat, double lng, String categoryId) async {
    final uri = Uri.parse('$_baseUrl/reports/duplicates?lat=$lat&lng=$lng&category_id=$categoryId');
    final response = await _get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> list = data['duplicates'] ?? [];
      return list.map((item) => DuplicateReportItem.fromJson(item)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse('$_baseUrl/locations/reverse-geocode?lat=$lat&lng=$lng');
    final response = await _get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {
      'address': '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}, Chennai',
      'city': 'Chennai',
      'ward_name': null,
    };
  }

  Future<Map<String, dynamic>> createReport(Map<String, dynamic> reportData) =>
      _post('/reports', reportData, 'Failed to create report');

  /// Officer: ACKNOWLEDGED / REJECTED. Field worker: IN_PROGRESS / BLOCKED.
  Future<void> updateReportStatus(String reportId, String status, {String? notes}) =>
      _post('/reports/$reportId/status', {'status': status, 'notes': notes}, 'Failed to update status');

  Future<void> assignReport(String reportId, String workerId, {String? notes}) =>
      _post('/reports/$reportId/assign', {'assigned_to': workerId, 'notes': notes}, 'Failed to assign report');

  Future<void> resolveReport({
    required String reportId,
    required String resolutionNotes,
    String? beforePhoto,
    String? afterPhoto,
  }) =>
      _post('/reports/$reportId/resolve', {
        'resolution_notes': resolutionNotes,
        'before_photo': beforePhoto,
        'after_photo': afterPhoto,
      }, 'Failed to resolve report');

  Future<void> verifyReport({
    required String reportId,
    required bool isFixed,
    String? feedback,
  }) =>
      _post('/reports/$reportId/verify', {'is_fixed': isFixed, 'feedback': feedback}, 'Failed to verify report');

  Future<String> uploadImage(String base64Data, {String filename = 'photo.jpg'}) async {
    final data = await _post('/reports/upload-image', {
      'base64_data': base64Data,
      'filename': filename,
    }, 'Failed to upload image to Supabase');
    return data['url'] as String;
  }

  /// Returns the new count and whether this user had already upvoted.
  Future<({int upvotes, bool alreadyUpvoted})> upvoteReport(String reportId) async {
    final data = await _post('/reports/$reportId/upvote', {}, 'Failed to upvote');
    return (upvotes: (data['upvotes'] as num).toInt(), alreadyUpvoted: data['already_upvoted'] == true);
  }

  Future<AnalyticsOverview> getAnalyticsOverview() async {
    final response = await _get(Uri.parse('$_baseUrl/analytics/overview'), headers: _headers);
    if (response.statusCode == 200) {
      return AnalyticsOverview.fromJson(jsonDecode(response.body));
    }
    throw _error(response, 'Failed to load analytics');
  }

  Future<List<StaffMember>> getWorkers({String? role}) async {
    final uri = Uri.parse('$_baseUrl/staff/workers').replace(queryParameters: role == null ? null : {'role': role});
    final response = await _get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => StaffMember.fromJson(item)).toList();
    }
    throw _error(response, 'Failed to load staff');
  }

  Future<List<Department>> getDepartments() async {
    final response = await _get(Uri.parse('$_baseUrl/staff/departments'), headers: _headers);
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => Department.fromJson(item)).toList();
    }
    throw _error(response, 'Failed to load departments');
  }
}
