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
      // Fetch both in parallel
      final (reps, an) = await (_api.getReports(status: _selectedFilter), _api.getAnalyticsOverview()).wait;
      if (!mounted) return;
      setState(() {
        _reports = reps;
        _analytics = an;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Could not load queue: ${_errText(e)}', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppTheme.danger : AppTheme.success),
    );
  }

  String _errText(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _assign(CivicReport report) async {
    final worker = await showDialog<StaffMember>(
      context: context,
      builder: (ctx) => _AssignWorkerDialog(report: report, api: _api),
    );
    if (worker == null) return;
    try {
      await _api.assignReport(report.id, worker.id, notes: 'Dispatched to ${worker.fullName}');
      _toast('Assigned ${report.publicId} to ${worker.fullName}');
      _loadData();
    } catch (e) {
      _toast('Assignment failed: ${_errText(e)}', error: true);
    }
  }

  Future<void> _setStatus(CivicReport report, String status, String notes, String done) async {
    try {
      await _api.updateReportStatus(report.id, status, notes: notes);
      _toast('${report.publicId} $done');
      _loadData();
    } catch (e) {
      _toast('Status update failed: ${_errText(e)}', error: true);
    }
  }

  Future<void> _reject(CivicReport report) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text('Reject ${report.publicId}?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text('Use this for invalid or spam reports. The citizen will see the rejection in the timeline.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: AppTheme.onAccent),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok == true) await _setStatus(report, 'REJECTED', 'Report rejected by department officer as invalid.', 'rejected');
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.ink));
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
              Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Authority Command Center',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink),
                  ),
                  Text(
                    '${appState.userName} • Greater Chennai Corporation',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                ),
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
                    _buildKpiCard('TOTAL REPORTS', '${_analytics!.totalReports}', AppTheme.ink, Icons.assignment_outlined),
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
                Text('QUEUE:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                const SizedBox(width: 8),
                _buildFilter('ALL', 'All Reports'),
                _buildFilter('SUBMITTED,ROUTED', 'New'),
                _buildFilter('ACKNOWLEDGED', 'Acknowledged'),
                _buildFilter('REOPENED', 'Reopened'),
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
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.ink),
                        ),
                        StatusBadge(status: rep.status),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Title
                    Text(
                      rep.title,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.ink),
                    ),
                    const SizedBox(height: 2),

                    // Address
                    Text(
                      '${rep.address ?? "Chennai"} • ${rep.wardName ?? "Ward 123"}',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),

                    // SLA status & assigned team
                    Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 12, color: AppTheme.textMuted),
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
                          Text('• ${rep.assignedTeam}', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
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
                        if (const {'ROUTED', 'REOPENED'}.contains(rep.status))
                          ElevatedButton.icon(
                            onPressed: () => _setStatus(rep, 'ACKNOWLEDGED', 'Officer verified coordinates and acknowledged ticket.', 'acknowledged'),
                            icon: const Icon(Icons.check, size: 12),
                            label: const Text('Acknowledge', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                        if (const {'ROUTED', 'ACKNOWLEDGED', 'REOPENED', 'ASSIGNED'}.contains(rep.status))
                          ElevatedButton.icon(
                            onPressed: () => _assign(rep),
                            icon: const Icon(Icons.person_add_alt_1, size: 12),
                            label: Text(rep.status == 'ASSIGNED' ? 'Reassign' : 'Assign Worker', style: const TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                        if (const {'ROUTED', 'ACKNOWLEDGED'}.contains(rep.status))
                          OutlinedButton.icon(
                            onPressed: () => _reject(rep),
                            icon: const Icon(Icons.block, size: 12),
                            label: const Text('Reject', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.danger,
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
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
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
        selectedColor: AppTheme.ink,
        labelStyle: TextStyle(
          color: isSel ? AppTheme.inkInverse : AppTheme.textSecondary,
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

/// Lets the officer pick which field worker receives the work order.
class _AssignWorkerDialog extends StatefulWidget {
  final CivicReport report;
  final ApiService api;

  const _AssignWorkerDialog({required this.report, required this.api});

  @override
  State<_AssignWorkerDialog> createState() => _AssignWorkerDialogState();
}

class _AssignWorkerDialogState extends State<_AssignWorkerDialog> {
  late final Future<List<StaffMember>> _workers = widget.api.getWorkers(role: 'FIELD_WORKER');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      title: Text('Assign ${widget.report.publicId}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
      content: SizedBox(
        width: 400,
        child: FutureBuilder<List<StaffMember>>(
          future: _workers,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return SizedBox(height: 80, child: Center(child: CircularProgressIndicator(color: AppTheme.ink)));
            }
            final workers = snap.data ?? [];
            if (snap.hasError || workers.isEmpty) {
              return Text('No field workers available.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary));
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: workers.map((w) {
                final current = w.id == widget.report.assignedTo;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.engineering_outlined, color: AppTheme.ink),
                  title: Text(w.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${w.departmentName ?? 'Field team'} • ${w.activeJobs} active job${w.activeJobs == 1 ? '' : 's'}${current ? ' • current' : ''}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  enabled: !current,
                  onTap: () => Navigator.pop(context, w),
                );
              }).toList(),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}
