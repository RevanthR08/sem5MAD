import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/app_state.dart';
import 'core/providers/theme_controller.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/custom_header.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/map/screens/explore_map_screen.dart';
import 'features/reports/screens/report_wizard_screen.dart';
import 'features/reports/screens/report_detail_screen.dart';
import 'features/authority/screens/authority_dashboard_screen.dart';
import 'features/field_worker/screens/field_worker_screen.dart';
import 'features/admin/screens/admin_dashboard_screen.dart';
import 'features/profile/screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: const CivicConnectApp(),
    ),
  );
}

class CivicConnectApp extends StatelessWidget {
  const CivicConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final theme = themeController.resolveTheme();
    return MaterialApp(
      title: 'Civic Connect',
      debugShowCheckedModeBanner: false,
      theme: theme,
      themeAnimationDuration: Duration.zero,
      // Screens read colors from AppTheme at build time, so remount the tree
      // when the brightness changes. Session state lives in AppState and survives.
      home: KeyedSubtree(key: ValueKey(theme.brightness), child: const RootGate()),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    if (!appState.isAuthenticated) {
      return const AuthScreen();
    }

    return const MainScaffold();
  }
}

class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // Each role only ever sees its own screens
    final destinationIndexMap = appState.allowedTabs;
    final activeTab = destinationIndexMap.contains(appState.activeTabIndex) ? appState.activeTabIndex : appState.homeTab;

    Widget currentBody;
    if (appState.selectedReportPublicId != null) {
      currentBody = ReportDetailScreen(publicId: appState.selectedReportPublicId!);
    } else {
      currentBody = switch (activeTab) {
        AppTab.map => const ExploreMapScreen(),
        AppTab.reportWizard => const ReportWizardScreen(),
        AppTab.authority => const AuthorityDashboardScreen(),
        AppTab.fieldOps => const FieldWorkerScreen(),
        AppTab.admin => const AdminDashboardScreen(),
        AppTab.profile => const ProfileScreen(),
        _ => const HomeScreen(),
      };
    }

    final destinations = destinationIndexMap.map(_destinationFor).toList();
    final currentNavIndex = destinationIndexMap.indexOf(activeTab);

    return Scaffold(
      appBar: const CustomHeader(),
      body: currentBody,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.inkInverse, // Black bar on dark theme, white on light
          border: Border(
            top: BorderSide(color: AppTheme.borderSubtle, width: 1),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: AppTheme.inkInverse,
            indicatorColor: AppTheme.ink.withValues(alpha: 0.12),
            indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // Almost square
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.ink);
              }
              return TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textMuted);
            }),
          ),
          child: NavigationBar(
            selectedIndex: currentNavIndex,
            onDestinationSelected: (idx) {
              appState.setActiveTab(destinationIndexMap[idx]);
            },
            height: 60,
            destinations: destinations,
          ),
        ),
      ),
    );
  }

  static NavigationDestination _destinationFor(int tab) {
    final (IconData icon, IconData selected, String label) = switch (tab) {
      AppTab.map => (Icons.map_outlined, Icons.map, 'Explore Map'),
      AppTab.reportWizard => (Icons.add_box_outlined, Icons.add_box, 'Report'),
      AppTab.authority => (Icons.shield_outlined, Icons.shield, 'Command Center'),
      AppTab.fieldOps => (Icons.construction_outlined, Icons.construction, 'Field Ops'),
      AppTab.admin => (Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, 'Admin'),
      AppTab.profile => (Icons.account_circle_outlined, Icons.account_circle, 'Profile'),
      _ => (Icons.home_outlined, Icons.home, 'Home'),
    };
    return NavigationDestination(
      icon: Icon(icon),
      selectedIcon: Icon(selected, color: AppTheme.ink),
      label: label,
    );
  }
}
