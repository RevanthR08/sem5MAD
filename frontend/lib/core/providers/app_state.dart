import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Screen indices used by MainScaffold.
class AppTab {
  static const citizenHome = 0;
  static const map = 1;
  static const reportWizard = 2;
  static const authority = 3;
  static const fieldOps = 4;
  static const admin = 5;
  static const profile = 6;
}

class AppState extends ChangeNotifier {
  bool _isAuthenticated = false;
  String _userName = '';
  String? _userId;
  String _currentRole = 'CITIZEN'; // CITIZEN, OFFICER, FIELD_WORKER, ADMIN
  int _activeTabIndex = AppTab.citizenHome;
  String? _selectedReportPublicId;
  String? _preselectedCategoryId;
  String? _departmentName;

  bool get isAuthenticated => _isAuthenticated;
  String get userName => _userName;
  String? get userId => _userId;
  String? get departmentName => _departmentName;
  String get currentRole => _currentRole;
  int get activeTabIndex => _activeTabIndex;
  String? get selectedReportPublicId => _selectedReportPublicId;
  String? get preselectedCategoryId => _preselectedCategoryId;

  bool get isCitizen => _currentRole == 'CITIZEN';
  bool get isOfficer => _currentRole == 'OFFICER';
  bool get isFieldWorker => _currentRole == 'FIELD_WORKER';
  bool get isAdmin => _currentRole == 'ADMIN';

  /// Officers and admins can triage and assign reports.
  bool get isStaff => isOfficer || isAdmin;

  String get roleLabel => const {
        'CITIZEN': 'Citizen',
        'OFFICER': 'Officer',
        'FIELD_WORKER': 'Field Staff',
        'ADMIN': 'Admin',
      }[_currentRole]!;

  /// Landing screen for the current role.
  int get homeTab => switch (_currentRole) {
        'OFFICER' => AppTab.authority,
        'FIELD_WORKER' => AppTab.fieldOps,
        'ADMIN' => AppTab.admin,
        _ => AppTab.citizenHome,
      };

  /// Screens the current role is allowed to open, in bottom-nav order.
  List<int> get allowedTabs => switch (_currentRole) {
        'OFFICER' => const [AppTab.authority, AppTab.map, AppTab.profile],
        'FIELD_WORKER' => const [AppTab.fieldOps, AppTab.map, AppTab.profile],
        'ADMIN' => const [AppTab.admin, AppTab.authority, AppTab.map, AppTab.profile],
        _ => const [AppTab.citizenHome, AppTab.map, AppTab.reportWizard, AppTab.profile],
      };

  /// Called after the user edits their profile.
  void updateName(String name) {
    _userName = name;
    ApiService().setActor(userId: _userId, role: _currentRole, name: name);
    notifyListeners();
  }

  /// Start a session for an account returned by /auth/login or /auth/register.
  void login({required String userId, required String name, required String role, String? departmentName}) {
    _isAuthenticated = true;
    _currentRole = role;
    _userName = name;
    _userId = userId;
    _departmentName = departmentName;
    ApiService().setActor(userId: _userId, role: role, name: name);
    _activeTabIndex = homeTab;
    _selectedReportPublicId = null;
    _preselectedCategoryId = null;
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _userName = '';
    _userId = null;
    _departmentName = null;
    _currentRole = 'CITIZEN';
    _activeTabIndex = AppTab.citizenHome;
    _selectedReportPublicId = null;
    _preselectedCategoryId = null;
    ApiService().clearActor();
    notifyListeners();
  }

  void setActiveTab(int index) {
    // Ignore requests for screens outside the role's area
    _activeTabIndex = allowedTabs.contains(index) ? index : homeTab;
    _selectedReportPublicId = null;
    notifyListeners();
  }

  void goHome() => setActiveTab(homeTab);

  void openReportDetail(String publicId) {
    _selectedReportPublicId = publicId;
    notifyListeners();
  }

  void closeReportDetail() {
    _selectedReportPublicId = null;
    notifyListeners();
  }

  void startReportWithCategory(String? categoryId) {
    if (!isCitizen) return;
    _preselectedCategoryId = categoryId;
    _activeTabIndex = AppTab.reportWizard;
    _selectedReportPublicId = null;
    notifyListeners();
  }
}
