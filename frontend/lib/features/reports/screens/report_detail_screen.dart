import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/status_badge.dart';

class ReportDetailScreen extends StatefulWidget {
  final String publicId;

  const ReportDetailScreen({super.key, required this.publicId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final ApiService _api = ApiService();
  CivicReport? _report;
  bool _loading = true;
  String? _errorMessage;

  final TextEditingController _feedbackController = TextEditingController();
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final rep = await _api.getReportDetail(widget.publicId);
      if (!mounted) return;
      setState(() {
        _report = rep;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _handleVerification(bool isFixed) async {
    if (_report == null) return;
    setState(() => _verifying = true);

    try {
      await _api.verifyReport(
        reportId: _report!.id,
        isFixed: isFixed,
        feedback: _feedbackController.text.trim().isEmpty ? (isFixed ? 'Confirmed fixed by citizen' : 'Problem still exists') : _feedbackController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFixed ? 'Thank you! Issue marked as RESOLVED.' : 'Ticket REOPENED and sent back to the officer.'),
          backgroundColor: isFixed ? AppTheme.success : AppTheme.danger,
        ),
      );
      await _loadReport();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification error: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Only the citizen who filed the report may confirm or reject the repair.
  /// Older seeded reports have no owner, so any citizen may verify those.
  bool _canVerify(CivicReport report, AppState appState) =>
      report.status == 'RESOLUTION_SUBMITTED' &&
      appState.isCitizen &&
      (report.userId == null || report.userId == appState.userId);

  Widget _photoUnavailable() => Container(
        height: 120,
        color: AppTheme.bgSecondary,
        alignment: Alignment.center,
        child: Icon(Icons.image_not_supported_outlined, color: AppTheme.textMuted),
      );

  Widget _infoBanner(IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.ink));
    }

    if (_errorMessage != null || _report == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 36, color: AppTheme.danger),
            const SizedBox(height: 8),
            Text('Could not load report ${widget.publicId}', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _loadReport, child: const Text('Retry')),
          ],
        ),
      );
    }

    final report = _report!;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button and Public ID
          Row(
            children: [
              IconButton(
                onPressed: () => appState.closeReportDetail(),
                icon: const Icon(Icons.arrow_back, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.bgCard,
                  padding: const EdgeInsets.all(6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.publicId,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    Text(
                      '${report.departmentName ?? 'Municipal Authority'} • ${report.wardName ?? 'Ward 123'}',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusBadge(status: report.status),
            ],
          ),

          const SizedBox(height: 16),

          // Main Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.ink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        report.categoryName ?? 'Civic Issue',
                        style: TextStyle(color: AppTheme.ink, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (report.slaInfo != null)
                      Text(
                        report.slaInfo!.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: report.slaInfo!.isBreached ? AppTheme.danger : AppTheme.success,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  report.title,
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  report.description,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        report.address ?? '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Assignment info for everyone once a field worker is attached
          if (report.assignedTeam != null && report.isOpen)
            _infoBanner(Icons.engineering_outlined, 'Assigned to ${report.assignedTeam}', AppTheme.ink),

          if (report.status == 'RESOLUTION_SUBMITTED' && !_canVerify(report, appState))
            _infoBanner(
              Icons.hourglass_top,
              appState.isCitizen
                  ? 'Repair submitted. Waiting for the reporting citizen to verify it.'
                  : 'Repair proof submitted. Waiting for citizen verification.',
              AppTheme.warning,
            ),

          if (report.status == 'REOPENED')
            _infoBanner(Icons.replay, 'Citizen reported the issue still exists. Ticket is back with the department.', AppTheme.danger),

          if (report.status == 'RESOLVED' && report.citizenVerified == true)
            _infoBanner(Icons.verified, 'Citizen confirmed this issue is fixed.', AppTheme.success),

          // CITIZEN VERIFICATION WIDGET: only the reporting citizen sees this
          if (_canVerify(report, appState)) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.warning, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_outlined, color: AppTheme.warning, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Citizen Resolution Verification',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Field team marked this issue as resolved. Is the problem fixed on your street?',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _feedbackController,
                    decoration: const InputDecoration(
                      hintText: 'Optional verification feedback...',
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _verifying ? null : () => _handleVerification(true),
                          icon: const Icon(Icons.check, size: 14),
                          label: const Text('✓ Yes, Fixed', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: AppTheme.onAccent),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _verifying ? null : () => _handleVerification(false),
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text('✗ Still Exists', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, side: BorderSide(color: AppTheme.danger)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Proof of Work: Before & After Photos
          if (report.resolutionBeforePhoto != null || report.resolutionAfterPhoto != null || report.thumbnailUrl != null) ...[
            Text('PHOTO EVIDENCE & REPAIR PROOF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (report.resolutionBeforePhoto != null || report.thumbnailUrl != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BEFORE REPAIR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.warning)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: report.resolutionBeforePhoto ?? report.thumbnailUrl!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) => _photoUnavailable(),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (report.resolutionAfterPhoto != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AFTER PROOF', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.success)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: report.resolutionAfterPhoto!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) => _photoUnavailable(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (report.resolutionNotes != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bgSecondary,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Text(
                  'Worker Notes: ${report.resolutionNotes!}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ],
            const SizedBox(height: 18),
          ],

          // Timeline
          Text('IMMUTABLE AUDIT TIMELINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.8)),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: report.timeline.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final ev = report.timeline[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: index == 0 ? AppTheme.ink : AppTheme.success,
                        shape: BoxShape.rectangle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  ev.notes ?? ev.eventType,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTheme.ink),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                ev.actorName ?? 'System',
                                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                          if (ev.newStatus != null)
                            Text(
                              'Status transition: ${ev.oldStatus ?? "START"} → ${ev.newStatus}',
                              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
