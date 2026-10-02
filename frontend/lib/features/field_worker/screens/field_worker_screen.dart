import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/status_badge.dart';

class FieldWorkerScreen extends StatefulWidget {
  const FieldWorkerScreen({super.key});

  @override
  State<FieldWorkerScreen> createState() => _FieldWorkerScreenState();
}

class _FieldWorkerScreenState extends State<FieldWorkerScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  List<CivicReport> _assignedTasks = [];
  bool _loading = true;
  bool _creatingDemo = false;

  static const _activeStatuses = {'ASSIGNED', 'IN_PROGRESS', 'BLOCKED', 'RESOLUTION_SUBMITTED'};
  static const _priorityRank = {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3};

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppTheme.danger : AppTheme.success),
    );
  }

  String _errText(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _loadTasks() async {
    final userId = Provider.of<AppState>(context, listen: false).userId;
    setState(() => _loading = true);
    try {
      // Only work orders assigned to this worker
      final reps = await _api.getReports(assignedTo: userId, status: _activeStatuses.join(','));
      reps.sort((a, b) {
        // Work still to do first, then by priority
        final doneA = a.status == 'RESOLUTION_SUBMITTED' ? 1 : 0;
        final doneB = b.status == 'RESOLUTION_SUBMITTED' ? 1 : 0;
        if (doneA != doneB) return doneA - doneB;
        return (_priorityRank[a.priority] ?? 9) - (_priorityRank[b.priority] ?? 9);
      });
      if (!mounted) return;
      setState(() {
        _assignedTasks = reps;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('Could not load work orders: ${_errText(e)}', error: true);
    }
  }

  Future<void> _startWork(CivicReport task) async {
    try {
      await _api.updateReportStatus(task.id, 'IN_PROGRESS',
          notes: 'Field maintenance team arrived on site and started repair work.');
      _toast('Status: IN PROGRESS. Work started on site!');
      _loadTasks();
    } catch (e) {
      _toast('Failed to start work: ${_errText(e)}', error: true);
    }
  }

  Future<void> _getDemoTask() async {
    setState(() => _creatingDemo = true);
    try {
      final task = await _api.createDemoFieldTask();
      _toast('New demo task ${task['public_id']} assigned to you');
      await _loadTasks();
    } catch (e) {
      _toast(_errText(e), error: true);
    } finally {
      if (mounted) setState(() => _creatingDemo = false);
    }
  }

  Future<void> _openGoogleMaps(CivicReport task) async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${task.latitude},${task.longitude}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _toast('Could not open maps for ${task.publicId}', error: true);
    }
  }

  /// Simulated navigation for demos: route from a mock depot to the site,
  /// with distance/ETA, an optional hand-off to Google Maps and "arrived".
  void _navigate(CivicReport task) {
    final site = LatLng(task.latitude, task.longitude);
    // Mock worker position: the ward depot ~1.5 km south-west of the site
    final start = LatLng(task.latitude - 0.010, task.longitude - 0.009);
    final km = const Distance().as(LengthUnit.Meter, start, site) / 1000;
    final etaMin = (km / 20 * 60).ceil(); // city traffic ~20 km/h

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Route to ${task.publicId}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink)),
            Text(task.address ?? '', style: TextStyle(fontSize: 11, color: AppTheme.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 220,
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.coordinates(coordinates: [start, site], padding: const EdgeInsets.all(40)),
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'org.civicconnect.app'),
                    PolylineLayer(polylines: [Polyline(points: [start, site], strokeWidth: 4, color: AppTheme.cyan)]),
                    MarkerLayer(markers: [
                      Marker(point: start, width: 30, height: 30, child: Icon(Icons.local_shipping, color: AppTheme.cyan, size: 26)),
                      Marker(point: site, width: 34, height: 34, child: Icon(Icons.location_on, color: AppTheme.danger, size: 34)),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.route, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text('${km.toStringAsFixed(1)} km  •  ~$etaMin min', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                const Spacer(),
                Text('Simulated route', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openGoogleMaps(task),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Google Maps', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (task.status == 'ASSIGNED' || task.status == 'BLOCKED') _startWork(task);
                    },
                    icon: const Icon(Icons.flag_outlined, size: 14),
                    label: Text(task.status == 'IN_PROGRESS' ? 'Arrived' : 'Arrived — Start', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Demo "after repair" photos, so proof can be submitted without a camera.
  String _sampleAfterPhoto(CivicReport task) => (task.categoryName ?? '').toLowerCase().contains('light')
      ? 'https://images.unsplash.com/photo-1517816743773-6e0fd518b4a6?w=800'
      : 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800';

  void _showResolutionDialog(CivicReport task) {
    final notesCtrl = TextEditingController();
    final String? beforeUrl = task.thumbnailUrl;
    String? afterUrl;
    bool submitting = false;
    bool uploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canSubmit = afterUrl != null && !uploading && !submitting;
            return AlertDialog(
              backgroundColor: AppTheme.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              title: Row(
                children: [
                  Icon(Icons.task_alt, color: AppTheme.ink, size: 20),
                  const SizedBox(width: 8),
                  Text('Submit Resolution Proof', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ticket: ${task.publicId} • ${task.title}', style: TextStyle(fontSize: 12, color: AppTheme.ink, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _proofTile(
                            'BEFORE (CITIZEN PHOTO)',
                            AppTheme.warning,
                            beforeUrl == null
                                ? _placeholder('No citizen photo')
                                : CachedNetworkImage(imageUrl: beforeUrl, height: 80, width: double.infinity, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _proofTile(
                            'AFTER PROOF PHOTO',
                            AppTheme.success,
                            uploading
                                ? Container(height: 80, color: AppTheme.bgSecondary, child: Center(child: CircularProgressIndicator(color: AppTheme.ink)))
                                : afterUrl == null
                                    ? _placeholder('Capture required')
                                    : CachedNetworkImage(imageUrl: afterUrl!, height: 80, width: double.infinity, fit: BoxFit.cover),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                        onPressed: uploading
                            ? null
                            : () async {
                                try {
                                  final XFile? file = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1200);
                                  if (file == null) return;
                                  setDialogState(() => uploading = true);
                                  final bytes = await file.readAsBytes();
                                  final url = await _api.uploadImage(base64Encode(bytes), filename: 'after_${file.name}');
                                  setDialogState(() {
                                    afterUrl = url;
                                    uploading = false;
                                  });
                                } catch (e) {
                                  setDialogState(() => uploading = false);
                                  _toast('Photo upload failed: ${_errText(e)}', error: true);
                                }
                              },
                        icon: const Icon(Icons.camera_alt_outlined, size: 14),
                        label: Text(afterUrl == null ? 'Camera' : 'Retake', style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Demo: submit proof without a real camera
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: uploading
                                ? null
                                : () => setDialogState(() {
                                      afterUrl = _sampleAfterPhoto(task);
                                      if (notesCtrl.text.trim().isEmpty) {
                                        notesCtrl.text = 'Repair completed on site and area cleared. Checked and safe for public use.';
                                      }
                                    }),
                            icon: const Icon(Icons.image_outlined, size: 14),
                            label: const Text('Sample Photo', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Resolution Summary Notes',
                        hintText: 'Describe actions taken to fix the problem...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ),
                ElevatedButton.icon(
                  onPressed: !canSubmit || notesCtrl.text.trim().isEmpty
                      ? null
                      : () async {
                          setDialogState(() => submitting = true);
                          try {
                            await _api.resolveReport(
                              reportId: task.id,
                              resolutionNotes: notesCtrl.text.trim(),
                              beforePhoto: beforeUrl,
                              afterPhoto: afterUrl,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _toast('Resolution submitted! Awaiting citizen verification.');
                            _loadTasks();
                          } catch (e) {
                            setDialogState(() => submitting = false);
                            _toast('Submit failed: ${_errText(e)}', error: true);
                          }
                        },
                  icon: submitting
                      ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.inkInverse))
                      : const Icon(Icons.check, size: 14),
                  label: const Text('Submit Proof'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _proofTile(String label, Color color, Widget image) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(2), child: image),
      ],
    );
  }

  Widget _placeholder(String text) => Container(
        height: 80,
        color: AppTheme.bgSecondary,
        alignment: Alignment.center,
        child: Text(text, style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      );

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.ink));
    }

    final pending = _assignedTasks.where((t) => t.status != 'RESOLUTION_SUBMITTED').length;

    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: AppTheme.ink,
      backgroundColor: AppTheme.bgCard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.ink,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.construction, color: AppTheme.inkInverse, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appState.userName,
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${appState.departmentName ?? 'Field Operations'} • GCC',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSecondary,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Text(
                      '$pending To Do',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.ink),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'My Work Orders',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                // Demo helper: always have something to work on
                OutlinedButton.icon(
                  onPressed: _creatingDemo ? null : _getDemoTask,
                  icon: _creatingDemo
                      ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.ink))
                      : const Icon(Icons.add_task, size: 14),
                  label: const Text('Get Demo Task', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Sorted by priority. Capture an after-repair photo when the job is done.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),

            if (_assignedTasks.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(28),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    Icon(Icons.task_alt, size: 40, color: AppTheme.success),
                    SizedBox(height: 8),
                    Text('All clear! No work orders assigned to you.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
            ] else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _assignedTasks.length,
                separatorBuilder: (c, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _buildTaskCard(_assignedTasks[index], appState),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(CivicReport task, AppState appState) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Text('${task.publicId} • ${task.priority}', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink, fontSize: 12)),
              StatusBadge(status: task.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            task.title,
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            task.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  task.address ?? '${task.latitude}, ${task.longitude}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
          if (task.slaInfo != null) ...[
            const SizedBox(height: 4),
            Text(
              task.slaInfo!.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: task.slaInfo!.isBreached ? AppTheme.danger : AppTheme.success),
            ),
          ],
          const SizedBox(height: 12),
          if (task.status == 'RESOLUTION_SUBMITTED')
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Proof submitted — awaiting citizen verification.', style: TextStyle(fontSize: 11, color: AppTheme.warning, fontWeight: FontWeight.w600)),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (task.status != 'RESOLUTION_SUBMITTED')
                OutlinedButton.icon(
                  onPressed: () => _navigate(task),
                  icon: const Icon(Icons.navigation_outlined, size: 12),
                  label: const Text('Navigate', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                ),
              if (task.status == 'ASSIGNED' || task.status == 'BLOCKED')
                ElevatedButton.icon(
                  onPressed: () => _startWork(task),
                  icon: const Icon(Icons.play_arrow_rounded, size: 14),
                  label: Text(task.status == 'BLOCKED' ? 'Resume Work' : 'Start Work', style: const TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                ),
              if (task.status == 'IN_PROGRESS')
                ElevatedButton.icon(
                  onPressed: () => _showResolutionDialog(task),
                  icon: const Icon(Icons.task_alt, size: 14),
                  label: const Text('Submit Resolution Proof', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                ),
              OutlinedButton(
                onPressed: () => appState.openReportDetail(task.publicId),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                child: const Text('Details', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
