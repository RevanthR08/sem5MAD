import 'package:flutter_test/flutter_test.dart';

import 'package:civic_connect/core/providers/app_state.dart';

void main() {
  group('AppState role routing', () {
    test('starts signed out', () {
      expect(AppState().isAuthenticated, isFalse);
    });

    test('each role lands on its own home and only sees its own tabs', () {
      final expected = {
        'CITIZEN': (AppTab.citizenHome, [AppTab.citizenHome, AppTab.map, AppTab.reportWizard, AppTab.profile]),
        'OFFICER': (AppTab.authority, [AppTab.authority, AppTab.map, AppTab.profile]),
        'FIELD_WORKER': (AppTab.fieldOps, [AppTab.fieldOps, AppTab.map, AppTab.profile]),
        'ADMIN': (AppTab.admin, [AppTab.admin, AppTab.authority, AppTab.map, AppTab.profile]),
      };
      expected.forEach((role, value) {
        final state = AppState()..login(userId: 'id-$role', name: 'Test', role: role);
        expect(state.activeTabIndex, value.$1, reason: role);
        expect(state.allowedTabs, value.$2, reason: role);
        expect(state.userId, 'id-$role', reason: role);
      });
    });

    test('officer cannot open citizen-only screens', () {
      final state = AppState()..login(userId: 'o1', name: 'Officer', role: 'OFFICER');
      state.setActiveTab(AppTab.reportWizard);
      expect(state.activeTabIndex, AppTab.authority);
      state.startReportWithCategory(null);
      expect(state.activeTabIndex, AppTab.authority);
    });

    test('admin is distinct from officer', () {
      final state = AppState()..login(userId: 'a1', name: 'Admin', role: 'ADMIN');
      expect(state.isAdmin, isTrue);
      expect(state.isOfficer, isFalse);
      expect(state.isStaff, isTrue);
    });

    test('logout clears identity', () {
      final state = AppState()..login(userId: 'c1', name: 'Citizen', role: 'CITIZEN');
      state.logout();
      expect(state.isAuthenticated, isFalse);
      expect(state.userId, isNull);
    });
  });
}
