import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/status_badge.dart';

class AuthorityDashboardScreen extends StatefulWidget {
  const AuthorityDashboardScreen({super.key});

  @override
  State<AuthorityDashboardScreen> createState() => _AuthorityDashboardScreenState();
}

class _AuthorityDashboardScreenState extends State<AuthorityDashboardScreen> {
  final ApiService _api = ApiService();
  List<CivicReport> _reports = [];
  AnalyticsOverview? _analytics;
  bool _loading = true;
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final reps = await _api.getReports(status: _selectedFilter);
      final an = await _api.getAnalyticsOverview();
      setState(() {
        _reports = reps;
        _analytics = an;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _quickAssign(CivicReport report) async {
    try {
      await _api.assignReport(
        report.id,
        'Roads Rapid Team 4 (Murugan S)',
        '10000000-0000-0000-0000-000000000003',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assigned ${report.publicId} to Rapid Team 4!'), backgroundColor: AppTheme.success),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assignment failed: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  Future<void> _quickAcknowledge(CivicReport report) async {
    try {
      await _api.updateReportStatus(report.id, {
        'status': 'ACKNOWLEDGED',
        'actor_name': 'Er. Rajesh V (Roads Officer)',
        'actor_role': 'DEPARTMENT_OFFICER',
        'notes': 'Officer verified coordinates and acknowledged ticket.',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket ${report.publicId} acknowledged!'), backgroundColor: AppTheme.success),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Authority Command Center',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const Text(
                    'Greater Chennai Corporation • Municipal Queue',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Responsive KPI Metric Cards (No bottom overflows!)
          if (_analytics != null) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                int cols = constraints.maxWidth < 650 ? 2 : 4;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: cols,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: constraints.maxWidth < 650 ? 1.9 : 2.3,
                  children: [
                    _buildKpiCard('TOTAL REPORTS', '${_analytics!.totalReports}', Colors.white, Icons.assignment_outlined),
                    _buildKpiCard('IN PROGRESS', '${_analytics!.inProgress}', AppTheme.warning, Icons.pending_actions_outlined),
                    _buildKpiCard('OVERDUE SLA', '${_analytics!.overdueReports}', AppTheme.danger, Icons.alarm_off_outlined),
                    _buildKpiCard('COMPLIANCE', '${_analytics!.slaCompliancePct.toInt()}%', AppTheme.success, Icons.task_alt_outlined),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],

          // Filter bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('QUEUE:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                const SizedBox(width: 8),
                _buildFilter('ALL', 'All Reports'),
                _buildFilter('SUBMITTED', 'New / Unassigned'),
                _buildFilter('ASSIGNED', 'Assigned'),
                _buildFilter('IN_PROGRESS', 'In Progress'),
                _buildFilter('RESOLUTION_SUBMITTED', 'Awaiting Verification'),
                _buildFilter('RESOLVED', 'Resolved'),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Reports Queue List (Vertical layout with no horizontal right overflows!)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reports.length,
            separatorBuilder: (c, i) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final rep = _reports[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(4), // Almost square
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: Public ID + Status + SLA
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          rep.publicId,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        StatusBadge(status: rep.status),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Title
                    Text(
                      rep.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                    ),
                    const SizedBox(height: 2),

                    // Address
                    Text(
                      '${rep.address ?? "Chennai"} • ${rep.wardName ?? "Ward 123"}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),

                    // SLA status & assigned team
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          rep.slaInfo?.label ?? '${rep.slaHours}h SLA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: rep.slaInfo?.isBreached == true ? AppTheme.danger : AppTheme.success,
                          ),
                        ),
                        if (rep.assignedTeam != null) ...[
                          const SizedBox(width: 8),
                          Text('• ${rep.assignedTeam}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Actions Row
                    Divider(color: AppTheme.borderSubtle.withValues(alpha: 0.5), height: 1),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (rep.status == 'SUBMITTED' || rep.status == 'ROUTED')
                          ElevatedButton.icon(
                            onPressed: () => _quickAcknowledge(rep),
                            icon: const Icon(Icons.check, size: 12),
                            label: const Text('Acknowledge', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                        if (rep.status == 'ACKNOWLEDGED' || rep.status == 'SUBMITTED' || rep.status == 'ROUTED')
                          ElevatedButton.icon(
                            onPressed: () => _quickAssign(rep),
                            icon: const Icon(Icons.person_add_alt_1, size: 12),
                            label: const Text('Assign Team 4', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => appState.openReportDetail(rep.publicId),
                          icon: const Icon(Icons.open_in_new, size: 12),
                          label: const Text('Inspect Details', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
              Icon(icon, color: color, size: 14),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildFilter(String val, String label) {
    final isSel = _selectedFilter == val;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        backgroundColor: AppTheme.bgCard,
        selectedColor: Colors.white,
        labelStyle: TextStyle(
          color: isSel ? Colors.black : AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedFilter = val);
            _loadData();
          }
        },
      ),
    );
  }
}
