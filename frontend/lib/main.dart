import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/app_state.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/custom_header.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/map/screens/explore_map_screen.dart';
import 'features/reports/screens/report_wizard_screen.dart';
import 'features/reports/screens/report_detail_screen.dart';
import 'features/authority/screens/authority_dashboard_screen.dart';
import 'features/field_worker/screens/field_worker_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const CivicConnectApp(),
    ),
  );
}

class CivicConnectApp extends StatelessWidget {
  const CivicConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Civic Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const RootGate(),
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

    // Active screen routing based on AppState
    Widget currentBody;
    if (appState.selectedReportPublicId != null) {
      currentBody = ReportDetailScreen(publicId: appState.selectedReportPublicId!);
    } else {
      switch (appState.activeTabIndex) {
        case 0:
          currentBody = const HomeScreen();
          break;
        case 1:
          currentBody = const ExploreMapScreen();
          break;
        case 2:
          currentBody = const ReportWizardScreen();
          break;
        case 3:
          currentBody = const AuthorityDashboardScreen();
          break;
        case 4:
          currentBody = const FieldWorkerScreen();
          break;
        default:
          currentBody = const HomeScreen();
      }
    }

    // Role-Based Bottom Navigation Destinations
    List<NavigationDestination> destinations = [];
    List<int> destinationIndexMap = [];

    if (appState.isCitizen) {
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: Colors.white),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map, color: Colors.white),
          label: 'Explore Map',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_box_outlined, size: 24, color: Colors.white),
          selectedIcon: Icon(Icons.add_box, size: 24, color: Colors.white),
          label: 'Report',
        ),
      ];
      destinationIndexMap = [0, 1, 2];
    } else if (appState.isOfficer || appState.isAdmin) {
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.shield_outlined),
          selectedIcon: Icon(Icons.shield, color: Colors.white),
          label: 'Authority',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map, color: Colors.white),
          label: 'Explore Map',
        ),
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: Colors.white),
          label: 'Citizen View',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_box_outlined, size: 24, color: Colors.white),
          selectedIcon: Icon(Icons.add_box, size: 24, color: Colors.white),
          label: 'Report',
        ),
      ];
      destinationIndexMap = [3, 1, 0, 2];
    } else {
      // Field Worker
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.construction_outlined),
          selectedIcon: Icon(Icons.construction, color: Colors.white),
          label: 'Field Ops',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map, color: Colors.white),
          label: 'Explore Map',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_box_outlined, size: 24, color: Colors.white),
          selectedIcon: Icon(Icons.add_box, size: 24, color: Colors.white),
          label: 'Report',
        ),
      ];
      destinationIndexMap = [4, 1, 2];
    }

    int currentNavIndex = destinationIndexMap.indexOf(appState.activeTabIndex);
    if (currentNavIndex == -1) currentNavIndex = 0;

    return Scaffold(
      appBar: const CustomHeader(),
      body: currentBody,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.black, // Pure black bottom nav as requested
          border: Border(
            top: BorderSide(color: AppTheme.borderSubtle, width: 1),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.black, // Pure black
            indicatorColor: Colors.white.withValues(alpha: 0.12),
            indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // Almost square
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white);
              }
              return const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textMuted);
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
}
