import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/theme/app_theme.dart';

/// City-wide oversight for the administrator: KPIs, category and ward load,
/// department workload and field staff utilisation. Triage itself happens in
/// the Command Center tab, which the admin shares with officers.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _api = ApiService();
  AnalyticsOverview? _analytics;
  List<Department> _departments = [];
  List<StaffMember> _staff = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getAnalyticsOverview(),
        _api.getDepartments(),
        _api.getWorkers(),
      ]);
      if (!mounted) return;
      setState(() {
        _analytics = results[0] as AnalyticsOverview;
        _departments = results[1] as List<Department>;
        _staff = results[2] as List<StaffMember>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.ink));
    }
    if (_error != null || _analytics == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: AppTheme.danger),
            const SizedBox(height: 8),
            Text(_error ?? 'Could not load analytics', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final a = _analytics!;
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.ink,
      backgroundColor: AppTheme.bgCard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('City Overview', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            Text('${appState.userName} • Greater Chennai Corporation', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            const SizedBox(height: 16),

            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 650;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: narrow ? 3 : 6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: narrow ? 1.35 : 1.8,
                  children: [
                    _kpi('TOTAL', '${a.totalReports}', AppTheme.ink),
                    _kpi('NEW', '${a.openReports}', AppTheme.ink),
                    _kpi('IN WORK', '${a.inProgress}', AppTheme.warning),
                    _kpi('TO VERIFY', '${a.awaitingVerification}', AppTheme.warning),
                    _kpi('RESOLVED', '${a.resolvedReports}', AppTheme.success),
                    _kpi('REOPENED', '${a.reopenedReports}', AppTheme.danger),
                    _kpi('CRITICAL', '${a.criticalActive}', AppTheme.danger),
                    _kpi('OVERDUE', '${a.overdueReports}', AppTheme.danger),
                    _kpi('SLA MET', '${a.slaCompliancePct.toInt()}%', AppTheme.success),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),
            _sectionTitle('REPORTS BY CATEGORY'),
            _barCard(a.categoryDistribution, 'category_name'),

            const SizedBox(height: 20),
            _sectionTitle('BUSIEST WARDS'),
            _barCard(a.wardPerformance, 'ward_name'),

            const SizedBox(height: 20),
            _sectionTitle('DEPARTMENT WORKLOAD'),
            _listCard(_departments
                .map((d) => _row(Icons.apartment_outlined, d.name, d.headOfficerName ?? '—', '${d.activeTickets} open'))
                .toList()),

            const SizedBox(height: 20),
            _sectionTitle('STAFF'),
            _listCard(_staff
                .map((s) => _row(
                      s.role == 'FIELD_WORKER' ? Icons.engineering_outlined : Icons.shield_outlined,
                      s.fullName,
                      '${s.role == 'FIELD_WORKER' ? 'Field Worker' : 'Officer'} • ${s.departmentName ?? '—'}',
                      '${s.activeJobs} active',
                    ))
                .toList()),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.8)),
      );

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.borderSubtle),
      );

  Widget _kpi(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  /// Horizontal bars for a list of {labelKey, count} maps.
  Widget _barCard(List<dynamic> items, String labelKey) {
    final rows = items.whereType<Map>().toList();
    final max = rows.fold<int>(1, (m, r) => ((r['count'] as num?)?.toInt() ?? 0) > m ? (r['count'] as num).toInt() : m);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: rows.isEmpty
          ? Text('No data yet', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))
          : Column(
              children: rows.map((r) {
                final count = (r['count'] as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text('${r[labelKey] ?? '—'}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: count / max,
                            minHeight: 8,
                            backgroundColor: AppTheme.bgSecondary,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(width: 24, child: Text('$count', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _listCard(List<Widget> rows) {
    return Container(
      decoration: _cardDecoration,
      child: rows.isEmpty
          ? Padding(
              padding: EdgeInsets.all(14),
              child: Text('No data yet', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            )
          : Column(children: rows),
    );
  }

  Widget _row(IconData icon, String title, String subtitle, String trailing) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: AppTheme.ink, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      trailing: Text(trailing, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.ink)),
    );
  }
}
