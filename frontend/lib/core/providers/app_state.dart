import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  bool _isAuthenticated = true; // Set to true with default session or can show auth screen
  String _userName = 'Revanth Citizen';
  String _currentRole = 'CITIZEN'; // CITIZEN, OFFICER, FIELD_WORKER, ADMIN
  int _activeTabIndex = 0; // 0: Home, 1: Map, 2: Report, 3: Authority, 4: Field
  String? _selectedReportPublicId;
  String? _preselectedCategoryId;

  bool get isAuthenticated => _isAuthenticated;
  String get userName => _userName;
  String get currentRole => _currentRole;
  int get activeTabIndex => _activeTabIndex;
  String? get selectedReportPublicId => _selectedReportPublicId;
  String? get preselectedCategoryId => _preselectedCategoryId;

  bool get isCitizen => _currentRole == 'CITIZEN';
  bool get isOfficer => _currentRole == 'OFFICER' || _currentRole == 'ADMIN';
  bool get isFieldWorker => _currentRole == 'FIELD_WORKER';
  bool get isAdmin => _currentRole == 'ADMIN';

  void login({required String name, required String role, String? password}) {
    _isAuthenticated = true;
    _userName = name.isNotEmpty ? name : (role == 'CITIZEN' ? 'Revanth Citizen' : role == 'OFFICER' ? 'Rajesh V (Officer)' : 'Murugan S (Field Worker)');
    _currentRole = role;

    // Automatically navigate to the appropriate home for the role
    if (role == 'OFFICER' || role == 'ADMIN') {
      _activeTabIndex = 3; // Authority Console
    } else if (role == 'FIELD_WORKER') {
      _activeTabIndex = 4; // Field Operations
    } else {
      _activeTabIndex = 0; // Citizen Home
    }
    _selectedReportPublicId = null;
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _activeTabIndex = 0;
    _selectedReportPublicId = null;
    notifyListeners();
  }

  void setRole(String role) {
    login(name: _userName, role: role);
  }

  void setActiveTab(int index) {
    _activeTabIndex = index;
    _selectedReportPublicId = null;
    notifyListeners();
  }

  void openReportDetail(String publicId) {
    _selectedReportPublicId = publicId;
    notifyListeners();
  }

  void closeReportDetail() {
    _selectedReportPublicId = null;
    notifyListeners();
  }

  void startReportWithCategory(String? categoryId) {
    _preselectedCategoryId = categoryId;
    _activeTabIndex = 2; // Jump to Report Wizard
    _selectedReportPublicId = null;
    notifyListeners();
  }
}
