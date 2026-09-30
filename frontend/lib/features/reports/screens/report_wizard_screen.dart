import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/theme/app_theme.dart';

class ReportWizardScreen extends StatefulWidget {
  const ReportWizardScreen({super.key});

  @override
  State<ReportWizardScreen> createState() => _ReportWizardScreenState();
}

class _ReportWizardScreenState extends State<ReportWizardScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  int _currentStep = 1; // 1 to 5

  List<Category> _categories = [];
  bool _loading = true;

  // Form State
  Category? _selectedCategory;
  Subcategory? _selectedSubcategory;
  LatLng _selectedLocation = const LatLng(13.0418, 80.2507); // Chennai Anna Salai
  String _addressText = 'Anna Salai, Teynampet, Chennai';
  String _wardName = 'Ward 114 (Teynampet)';
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  String _severity = 'HIGH';
  String _selectedPhotoUrl = 'https://images.unsplash.com/photo-1515162816999-a0c47dc192f7?w=800';
  bool _isUploadingPhoto = false;

  // Smart Fields
  bool _trafficHazard = true;
  bool _dangerToPedestrians = true;

  // Duplicate Check State
  bool _isCheckingDuplicates = false;
  List<DuplicateReportItem> _detectedDuplicates = [];
  bool _duplicateAcknowledged = false;

  // Submitting
  bool _isSubmitting = false;

  // Category Presets
  final Map<String, List<Map<String, String>>> _categoryPresets = {
    'roads': [
      {'label': 'Pothole Crater', 'url': 'https://images.unsplash.com/photo-1515162816999-a0c47dc192f7?w=800'},
      {'label': 'Broken Footpath', 'url': 'https://images.unsplash.com/photo-1541888946425-d0fbb186156f?w=800'},
    ],
    'lighting': [
      {'label': 'Streetlight Completely Off', 'url': 'https://images.unsplash.com/photo-1509114397022-ed747cca3f65?w=800'},
      {'label': 'Flickering / Dim Lamp', 'url': 'https://images.unsplash.com/photo-1517816743773-6e0fd518b4a6?w=800'},
    ],
    'waste': [
      {'label': 'Overflowing Garbage Bin', 'url': 'https://images.unsplash.com/photo-1605600659873-d808a13e4d2a?w=800'},
      {'label': 'Illegal Debris Dumping', 'url': 'https://images.unsplash.com/photo-1530587191325-3db32d826c18?w=800'},
    ],
    'drainage': [
      {'label': 'Flooded Road / Drain Clog', 'url': 'https://images.unsplash.com/photo-1547683905-f686c993aae5?w=800'},
      {'label': 'Broken Drain Slab', 'url': 'https://images.unsplash.com/photo-1517646287270-a5a9ca602e5c?w=800'},
    ],
    'water': [
      {'label': 'Pipeline Burst', 'url': 'https://images.unsplash.com/photo-1584467735871-8e85353a8413?w=800'},
      {'label': 'Contaminated Water', 'url': 'https://images.unsplash.com/photo-1538300342682-cf57afb97285?w=800'},
    ],
    'safety': [
      {'label': 'Fallen Tree Branch', 'url': 'https://images.unsplash.com/photo-1527482797697-8795b05a13fe?w=800'},
      {'label': 'Construction Pit', 'url': 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800'},
    ]
  };

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      final cats = await _api.getCategories();
      setState(() {
        _categories = cats;
        if (appState.preselectedCategoryId != null) {
          _selectedCategory = cats.firstWhere(
            (c) => c.id == appState.preselectedCategoryId,
            orElse: () => cats.first,
          );
        } else if (cats.isNotEmpty) {
          _selectedCategory = cats.first;
        }
        if (_selectedCategory != null && _selectedCategory!.subcategories.isNotEmpty) {
          _selectedSubcategory = _selectedCategory!.subcategories.first;
        }
        _updateCategoryDefaults();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _updateCategoryDefaults() {
    if (_selectedCategory == null) return;
    final catCode = _selectedCategory!.code.toLowerCase();
    final presets = _categoryPresets[catCode] ?? _categoryPresets['roads']!;
    _selectedPhotoUrl = presets.first['url']!;

    final subName = _selectedSubcategory?.name ?? _selectedCategory!.name;
    _titleController.text = '$subName Issue';
    _descController.text = 'Reported $subName on ${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)}. Requires municipal inspection and repair.';
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() => _isUploadingPhoto = true);
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);

      // Upload to Supabase Storage Bucket via FastAPI
      final publicUrl = await _api.uploadImage(base64String, filename: file.name);

      setState(() {
        _selectedPhotoUrl = publicUrl;
        _isUploadingPhoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo uploaded to Supabase Storage bucket!'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  Future<void> _onLocationChanged(LatLng latLng) async {
    setState(() => _selectedLocation = latLng);
    try {
      final res = await _api.reverseGeocode(latLng.latitude, latLng.longitude);
      setState(() {
        _addressText = res['address'] ?? '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';
        _wardName = res['ward_name'] ?? 'Ward 123 (Mylapore)';
      });
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _checkForDuplicatesAndProceed() async {
    if (_selectedCategory == null) return;
    setState(() => _isCheckingDuplicates = true);
    try {
      final dups = await _api.checkDuplicates(
        _selectedLocation.latitude,
        _selectedLocation.longitude,
        _selectedCategory!.id,
      );
      setState(() {
        _detectedDuplicates = dups;
        _isCheckingDuplicates = false;
      });

      if (dups.isNotEmpty && !_duplicateAcknowledged) {
        _showDuplicateDialog();
      } else {
        setState(() => _currentStep = 5); // Review
      }
    } catch (e) {
      setState(() {
        _isCheckingDuplicates = false;
        _currentStep = 5;
      });
    }
  }

  void _showDuplicateDialog() {
    final appState = Provider.of<AppState>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // Almost square
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 24),
              const SizedBox(width: 8),
              Text('Similar Issue Nearby', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Civic Connect detected reports in this category within 50m of your location. Upvote the existing report to escalate it faster!',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                ..._detectedDuplicates.map((d) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSecondary,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        if (d.thumbnailUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: CachedNetworkImage(
                              imageUrl: d.thumbnailUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.publicId,
                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                d.title,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${d.distanceMeters.toStringAsFixed(0)}m away • ${d.status}',
                                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _api.upvoteReport(d.id);
                            appState.openReportDetail(d.publicId);
                          },
                          icon: const Icon(Icons.thumb_up, size: 12),
                          label: const Text('Upvote'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _duplicateAcknowledged = true;
                  _currentStep = 5;
                });
              },
              child: const Text('Different Issue (Proceed)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitFinalReport() async {
    final appState = Provider.of<AppState>(context, listen: false);
    setState(() => _isSubmitting = true);

    try {
      final res = await _api.createReport({
        'title': _titleController.text.trim().isEmpty ? '${_selectedCategory?.name} Issue' : _titleController.text.trim(),
        'description': _descController.text.trim().isEmpty ? 'Civic complaint reported via mobile app.' : _descController.text.trim(),
        'category_id': _selectedCategory!.id,
        'subcategory_id': _selectedSubcategory?.id,
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
        'address': _addressText,
        'landmark': _landmarkController.text.trim(),
        'severity': _severity,
        'is_anonymous': false,
        'reporter_name': appState.userName,
        'reporter_contact': '+919876543210',
        'photo_urls': [_selectedPhotoUrl],
        'custom_fields': {
          'traffic_hazard': _trafficHazard,
          'danger_to_pedestrians': _dangerToPedestrians,
        }
      });

      setState(() => _isSubmitting = false);
      final publicId = res['public_id'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report $publicId submitted to ${_selectedCategory?.name} department!'),
          backgroundColor: AppTheme.success,
        ),
      );
      appState.openReportDetail(publicId);
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactStepProgress(),
          const SizedBox(height: 18),
          if (_currentStep == 1) _buildStep1Category(),
          if (_currentStep == 2) _buildStep2Location(),
          if (_currentStep == 3) _buildStep3Evidence(),
          if (_currentStep == 4) _buildStep4Details(),
          if (_currentStep == 5) _buildStep5Review(),
        ],
      ),
    );
  }

  // Compact Step Progress Bar (Never Overflows!)
  Widget _buildCompactStepProgress() {
    final stepNames = ['Category', 'Location', 'Evidence', 'Details', 'Review'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'STEP $_currentStep OF 5: ${stepNames[_currentStep - 1].toUpperCase()}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.8),
          ),
          Row(
            children: List.generate(5, (idx) {
              final step = idx + 1;
              final isDone = _currentStep > step;
              final isActive = _currentStep == step;

              return Container(
                width: 14,
                height: 4,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: isDone ? AppTheme.success : isActive ? Colors.white : AppTheme.borderSubtle,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // STEP 1: CATEGORY (Clean, 2-column or list on small screens, no overflow!)
  Widget _buildStep1Category() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What problem do you want to report?', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('Select category to trigger automated GIS department routing.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 16),

        LayoutBuilder(
          builder: (context, constraints) {
            // Adaptive column count: 2 on mobile, 3 on tablet/desktop
            int count = constraints.maxWidth < 600 ? 2 : 3;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2, // Generous ratio to prevent any overflow!
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory?.id == cat.id;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                      _selectedSubcategory = cat.subcategories.isNotEmpty ? cat.subcategories.first : null;
                      _updateCategoryDefaults();
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.1) : AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? Colors.white : AppTheme.borderSubtle,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          cat.code == 'lighting'
                              ? Icons.lightbulb_outline
                              : cat.code == 'waste'
                                  ? Icons.delete_outline
                                  : cat.code == 'drainage'
                                      ? Icons.water_drop_outlined
                                      : cat.code == 'water'
                                          ? Icons.waves
                                          : cat.code == 'safety'
                                              ? Icons.warning_amber_rounded
                                              : Icons.construction,
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${cat.defaultSlaHours}h SLA',
                                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),

        // Subcategories Chips
        if (_selectedCategory != null && _selectedCategory!.subcategories.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Specify Problem Type', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedCategory!.subcategories.map((sub) {
              final isSel = _selectedSubcategory?.id == sub.id;
              return ChoiceChip(
                label: Text(sub.name),
                selected: isSel,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                backgroundColor: AppTheme.bgCard,
                selectedColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSel ? Colors.black : AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedSubcategory = sub;
                      _updateCategoryDefaults();
                    });
                  }
                },
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _currentStep = 2),
            icon: const Icon(Icons.arrow_forward, size: 14),
            label: const Text('Next: Set Location'),
          ),
        ),
      ],
    );
  }

  // STEP 2: LOCATION
  Widget _buildStep2Location() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 2: Pin Location on Map', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('Tap or drag the map pin. PostGIS reverse geocodes the exact Ward.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 14),

        // Map container
        Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15.0,
              onTap: (tapPosition, point) => _onLocationChanged(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'org.civicconnect.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.location_on, size: 36, color: AppTheme.danger),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Row(
            children: [
              const Icon(Icons.pin_drop_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_addressText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Auto-routed: $_wardName • Greater Chennai Corporation', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: () => _onLocationChanged(const LatLng(13.0418, 80.2507)),
                icon: const Icon(Icons.my_location, size: 12),
                label: const Text('GPS', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 1),
              child: const Text('Back'),
            ),
            ElevatedButton.icon(
              onPressed: () => setState(() => _currentStep = 3),
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: const Text('Next: Photo Evidence'),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 3: EVIDENCE (Camera capture, File upload to Supabase bucket, and Category-Aligned Presets!)
  Widget _buildStep3Evidence() {
    final catCode = _selectedCategory?.code.toLowerCase() ?? 'roads';
    final presets = _categoryPresets[catCode] ?? _categoryPresets['roads']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 3: Capture Photo Evidence', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          'Upload photo of the ${_selectedCategory?.name ?? "issue"}. Stored in your Supabase S3 bucket.',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),

        // Photo Preview Card
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: _isUploadingPhoto
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: Colors.white), SizedBox(height: 8), Text('Uploading to Supabase S3 bucket...', style: TextStyle(fontSize: 11))]))
              : CachedNetworkImage(
                  imageUrl: _selectedPhotoUrl,
                  fit: BoxFit.cover,
                  placeholder: (c, u) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorWidget: (c, u, e) => const Center(child: Icon(Icons.image_not_supported_outlined, size: 36)),
                ),
        ),

        const SizedBox(height: 14),

        // CAMERA & GALLERY UPLOAD BUTTONS (User Requirement: access camera / file picker)
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isUploadingPhoto ? null : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: const Text('Take Camera Photo', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isUploadingPhoto ? null : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: const Text('Upload from Files', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Category-Specific Presets (Aligned with the chosen category!)
        Text('Or select a preset for ${_selectedCategory?.name ?? "this issue"}:', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
        const SizedBox(height: 8),

        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: presets.map((p) {
            final isSel = _selectedPhotoUrl == p['url'];
            return ActionChip(
              avatar: isSel ? const Icon(Icons.check, size: 14, color: Colors.black) : null,
              label: Text(p['label']!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              backgroundColor: isSel ? Colors.white : AppTheme.bgCard,
              labelStyle: TextStyle(
                color: isSel ? Colors.black : AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: isSel ? Colors.white : AppTheme.borderSubtle),
              onPressed: () {
                setState(() => _selectedPhotoUrl = p['url']!);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 2),
              child: const Text('Back'),
            ),
            ElevatedButton.icon(
              onPressed: () => setState(() => _currentStep = 4),
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: const Text('Next: Details'),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 4: DETAILS & DYNAMIC SMART FIELDS
  Widget _buildStep4Details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 4: Issue Description & Priority', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('Details are forwarded directly to the municipal engineer dispatch desk.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 16),

        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Report Title',
            hintText: 'e.g. Streetlight Flickering / Dim Lamp',
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _descController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Problem Description',
            hintText: 'Describe exact condition, impact, and safety hazards...',
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _landmarkController,
          decoration: const InputDecoration(
            labelText: 'Nearby Landmark / Pole Number',
            hintText: 'e.g. Pole #SL-12, Opposite Apollo Pharmacy',
          ),
        ),
        const SizedBox(height: 16),

        // Severity Selector
        const Text('SEVERITY LEVEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Row(
          children: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].map((s) {
            final isSel = _severity == s;
            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: ChoiceChip(
                label: Text(s),
                selected: isSel,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                backgroundColor: AppTheme.bgCard,
                selectedColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSel ? Colors.black : AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                onSelected: (val) {
                  if (val) setState(() => _severity = s);
                },
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),

        // Smart Category Fields
        CheckboxListTile(
          title: const Text('Poses immediate traffic risk / pedestrian hazard', style: TextStyle(fontSize: 12)),
          value: _trafficHazard,
          activeColor: Colors.white,
          checkColor: Colors.black,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) => setState(() => _trafficHazard = val ?? false),
        ),
        CheckboxListTile(
          title: const Text('Corridor completely dark / obstructed walkway', style: TextStyle(fontSize: 12)),
          value: _dangerToPedestrians,
          activeColor: Colors.white,
          checkColor: Colors.black,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) => setState(() => _dangerToPedestrians = val ?? false),
        ),

        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 3),
              child: const Text('Back'),
            ),
            ElevatedButton.icon(
              onPressed: _isCheckingDuplicates ? null : _checkForDuplicatesAndProceed,
              icon: _isCheckingDuplicates
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.arrow_forward, size: 14),
              label: const Text('Next: Duplicate Check & Review'),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 5: REVIEW & DISPATCH
  Widget _buildStep5Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 5: Review & Submit Ticket', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        const Text('Confirm your report details before dispatching to Greater Chennai Corporation.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 16),

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
                  Text(
                    _selectedCategory?.name ?? 'Civic Issue',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('$_severity PRIORITY', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Text(
                _titleController.text,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                _descController.text,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('$_addressText ($_wardName)', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: CachedNetworkImage(
                  imageUrl: _selectedPhotoUrl,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 4),
              child: const Text('Back'),
            ),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitFinalReport,
              icon: _isSubmitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.send_rounded, size: 14),
              label: const Text('Submit Ticket to GCC'),
            ),
          ],
        ),
      ],
    );
  }
}
