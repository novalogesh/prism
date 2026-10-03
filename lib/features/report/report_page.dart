import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/prism_section_heading.dart';
import '../../core/models/hazard_report.dart';
import '../../core/storage/report_storage.dart';
import '../camera/camera_page.dart';
import '../reports/reports_page.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String? selectedHazard;
  String selectedRisk = 'ASSESS RISK';
  bool locationCaptured = false;

  final ReportStorage _reportStorage = ReportStorage();
  String? attachedPhotoPath;
  double? latitude;
  double? longitude;
String? locationName;

  final TextEditingController descriptionController =
      TextEditingController();

  final TextEditingController reporterAddressController =
      TextEditingController();

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRISM',
              style: AppTextStyles.pageTitle,
            ),
            Text(
              'Report Hazard',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const PrismSectionHeading(
                title: 'STEP 01',
                trailing: 'HAZARD TYPE',
              ),

              const SizedBox(height: AppSpacing.md),

              _HazardTypeSelector(
                selected: selectedHazard,
                onSelected: (value) {
                  setState(() {
                    selectedHazard = value;
                  });
                },
              ),

              const SizedBox(height: AppSpacing.section),

              const PrismSectionHeading(
                title: 'STEP 02',
                trailing: 'PHOTO EVIDENCE',
              ),

              const SizedBox(height: AppSpacing.md),

              _PhotoCaptureCard(
                onPressed: () async {
                  final photoPath =
                      await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) =>
                          const PrismCameraPage(),
                    ),
                  );

                  if (photoPath != null && mounted) {
  setState(() {
    attachedPhotoPath = photoPath;
  });

  _showMessage(
    'Photo attached to this report.',
  );
}
                },
              ),

              const SizedBox(height: AppSpacing.section),

              const PrismSectionHeading(
                title: 'STEP 03',
                trailing: 'LOCATION',
              ),

              const SizedBox(height: AppSpacing.md),

              _LocationCard(
                  captured: locationCaptured,
                  locationName: locationName,
                  latitude: latitude,
                  longitude: longitude,
                  onPressed: _captureLocation,
                ),

              const SizedBox(height: AppSpacing.section),

              PrismSectionHeading(
                title: 'STEP 04',
                trailing: selectedHazard == 'OTHER'
                    ? 'EXACT PROBLEM'
                    : 'DESCRIPTION',
              ),

              const SizedBox(height: AppSpacing.md),

              if (selectedHazard == 'OTHER')
                const Padding(
                  padding: EdgeInsets.only(
                    bottom: AppSpacing.sm,
                  ),
                  child: Text(
                    'Please describe exactly what you observed. '
                    'This helps PRISM classify hazards that do not '
                    'fit the listed categories.',
                    style: AppTextStyles.bodySecondary,
                  ),
                ),

              TextField(
                controller: descriptionController,
                maxLines: 5,
                maxLength: 750,
                decoration: InputDecoration(
                  hintText: selectedHazard == 'OTHER'
                      ? 'What exactly is the problem?'
                      : 'Describe what you observed...',
                  alignLabelWithHint: true,
                  suffixIcon: selectedHazard == 'OTHER'
                      ? const Icon(
                          Icons.priority_high,
                        )
                      : null,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              TextField(
                controller: reporterAddressController,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'REPORTER PROVIDED ADDRESS',
                  hintText:
                      'Enter the exact place, street, landmark, building, or nearby location',
                  prefixIcon: Icon(
                    Icons.edit_location_alt_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: AppSpacing.section),

              const PrismSectionHeading(
                title: 'STEP 05',
                trailing: 'RISK ASSESSMENT',
              ),

              const SizedBox(height: AppSpacing.md),

              _RiskSelector(
                selected: selectedRisk,
                onSelected: (risk) {
                  setState(() {
                    selectedRisk = risk;
                  });
                },
              ),

              const SizedBox(height: AppSpacing.section),

              _OfflineReportNotice(),

              const SizedBox(height: AppSpacing.xl),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _submitReport,
                  icon: const Icon(
                    Icons.send_outlined,
                  ),
                  label: const Text(
                    'SUBMIT REPORT',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _captureLocation() async {
    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage(
          'Please enable location services.',
        );
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _showMessage(
          'Location permission was denied.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage(
          'Location permission is permanently denied.',
        );
        return;
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      String? resolvedLocationName;

      try {
        final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse'
          '?format=jsonv2'
          '&lat=${position.latitude}'
          '&lon=${position.longitude}',
        );

        final response = await http.get(
          uri,
          headers: {
            'User-Agent': 'PRISM-Flood-Hazard-App/1.0',
          },
        );

        if (response.statusCode == 200) {
          final data =
              jsonDecode(response.body) as Map<String, dynamic>;

          final address =
              data['address'] as Map<String, dynamic>?;

          if (address != null) {
            final parts = <String>[];

            final landmark =
                address['amenity'] ??
                address['building'] ??
                address['shop'] ??
                address['tourism'] ??
                address['leisure'];

            final road = address['road'];
            final neighbourhood =
                address['neighbourhood'] ??
                address['quarter'] ??
                address['suburb'];
            final city =
                address['city'] ??
                address['town'] ??
                address['village'] ??
                address['municipality'];

            if (landmark is String &&
                landmark.trim().isNotEmpty) {
              parts.add(landmark.trim());
            }

            if (road is String &&
                road.trim().isNotEmpty &&
                !parts.contains(road.trim())) {
              parts.add(road.trim());
            }

            if (neighbourhood is String &&
                neighbourhood.trim().isNotEmpty &&
                !parts.contains(neighbourhood.trim())) {
              parts.add(neighbourhood.trim());
            }

            if (city is String &&
                city.trim().isNotEmpty &&
                !parts.contains(city.trim())) {
              parts.add(city.trim());
            }

            if (parts.isNotEmpty) {
              resolvedLocationName = parts.join(', ');
            }
          }

          resolvedLocationName ??=
              data['display_name'] as String?;
        }
      } catch (_) {
        resolvedLocationName = null;
      }

      if (!mounted) return;

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
        locationName = resolvedLocationName;
        locationCaptured = true;
      });

      if (resolvedLocationName != null &&
          resolvedLocationName.isNotEmpty) {
        _showMessage(
          'Location captured: $resolvedLocationName',
        );
      } else {
        _showMessage(
          'GPS location captured. Location name unavailable offline.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not capture location: $e',
      );
    }
  }
  Future<void> _submitReport() async {
    if (selectedHazard == null || selectedHazard!.isEmpty) {
      _showMessage(
        'Please select the hazard type.',
      );
      return;
    }

    if (!locationCaptured) {
      _showMessage(
        'Please capture the hazard location.',
      );
      return;
    }

    if (selectedHazard == 'OTHER' &&
        descriptionController.text.trim().isEmpty) {
      _showMessage(
        'Please describe exactly what the problem is.',
      );
      return;
    }

    final now = DateTime.now();

    final report = HazardReport(
      id: 'PRISM-${now.microsecondsSinceEpoch}',
      hazardType: selectedHazard!,
      severity: selectedRisk == 'ASSESS RISK' ? null : selectedRisk,
      description: descriptionController.text.trim(),
      photoPath: attachedPhotoPath,
      capturedAt: now,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      reporterAddress: reporterAddressController.text.trim().isEmpty
          ? null
          : reporterAddressController.text.trim(),
      status: 'UNSYNCED',
      sharedNearby: false,
      createdAt: now,
      syncState: ReportSyncState.unsynced,
      lifecycleStatus: HazardLifecycleStatus.underReview,
    );

    try {
      await _reportStorage.saveReport(report);

      if (!mounted) return;

      setState(() {
        selectedHazard = null;
        selectedRisk = 'ASSESS RISK';
        attachedPhotoPath = null;
        latitude = null;
        longitude = null;
        locationName = null;
        locationCaptured = false;
        reporterAddressController.clear();
        descriptionController.clear();
      });

      _showMessage(
        'Report saved offline successfully.',
      );

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ReportsPage(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not save report: $e',
      );
    }
  }
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }


}


// ------------------------------------------------------------
// HAZARD TYPE
// ------------------------------------------------------------

class _HazardTypeSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;

  const _HazardTypeSelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final hazards = [
      ('FLOODED ROAD', 'FLOOD', Icons.water),
      ('OPEN MANHOLE', 'OPEN MANHOLE', Icons.warning_amber_rounded),
      ('DAMAGED ROAD', 'DAMAGED ROAD', Icons.construction_outlined),
      ('FALLEN TREE', 'FALLEN TREE', Icons.park_outlined),
      ('ELECTRIC HAZARD', 'ELECTRICAL', Icons.bolt_outlined),
      ('WATER LOGGING', 'WATER LOGGING', Icons.water_drop_outlined),
      ('OTHER', 'OTHER', Icons.more_horiz),
    ];

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: hazards.map((hazard) {
        final isSelected = selected == hazard.$1;

        return ChoiceChip(
          selected: isSelected,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hazard.$3,
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(hazard.$2),
            ],
          ),
          onSelected: (_) {
            if (selected == hazard.$1) {
              onSelected('');
            } else {
              onSelected(hazard.$1);
            }
          },
        );
      }).toList(),
    );
  }
}


// ------------------------------------------------------------
// PHOTO
// ------------------------------------------------------------

class _PhotoCaptureCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _PhotoCaptureCard({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        height: 175,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.borderDark,
          ),
        ),
        child: const Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 42,
            ),

            SizedBox(height: 12),

            Text(
              'TAKE PHOTO',
              style: AppTextStyles.sectionTitle,
            ),

            SizedBox(height: 5),

            Text(
              'Use the camera to document the hazard',
              style: AppTextStyles.bodySecondary,
            ),

            SizedBox(height: 8),

            Text(
              'GPS + TIME WILL BE RECORDED',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}


// ------------------------------------------------------------
// LOCATION
// ------------------------------------------------------------

class _LocationCard extends StatelessWidget {
  final bool captured;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final VoidCallback onPressed;

  const _LocationCard({
    required this.captured,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.borderDark,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            captured
                ? Icons.location_on
                : Icons.location_searching,
            size: 30,
            color: captured
                ? AppColors.safe
                : AppColors.textPrimary,
          ),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  captured
                      ? 'LOCATION CAPTURED'
                      : 'LOCATION NOT CAPTURED',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                if (captured && locationName != null)
                  Text(
                    locationName!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySecondary,
                  )
                else
                  Text(
                    captured
                        ? 'GPS coordinates ready'
                        : 'Required for accurate hazard mapping',
                    style: AppTextStyles.bodySecondary,
                  ),

                if (captured &&
                    latitude != null &&
                    longitude != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    ', ',
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          OutlinedButton(
            onPressed: onPressed,
            child: Text(
              captured ? 'UPDATE' : 'CAPTURE',
            ),
          ),
        ],
      ),
    );
  }
}


// ------------------------------------------------------------
// RISK
// ------------------------------------------------------------

class _RiskSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _RiskSelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final risks = [
      ('LOW', AppColors.safe),
      ('MODERATE', AppColors.warning),
      ('HIGH', AppColors.danger),
      ('CRITICAL', AppColors.danger),
    ];

    return Column(
      children: risks.map((risk) {
        final isSelected = selected == risk.$1;

        return Container(
          margin: const EdgeInsets.only(
            bottom: AppSpacing.sm,
          ),
          child: InkWell(
            onTap: () {
              onSelected(risk.$1);
            },
            child: Container(
              padding: const EdgeInsets.all(
                AppSpacing.md,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected
                      ? risk.$2
                      : AppColors.border,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [

                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: risk.$2,
                  ),

                  const SizedBox(width: AppSpacing.md),

                  Expanded(
                    child: Text(
                      risk.$1,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .7,
                      ),
                    ),
                  ),

                  Text(
                    _riskDescription(risk.$1),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _riskDescription(String risk) {
    switch (risk) {
      case 'LOW':
        return 'Minor';
      case 'MODERATE':
        return 'Caution';
      case 'HIGH':
        return 'Danger';
      case 'CRITICAL':
        return 'Immediate danger';
      default:
        return '';
    }
  }
}


// ------------------------------------------------------------
// OFFLINE NOTICE
// ------------------------------------------------------------

class _OfflineReportNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [

          Icon(
            Icons.cloud_off_outlined,
            size: 21,
          ),

          SizedBox(width: AppSpacing.sm),

          Expanded(
            child: Text(
              'No internet? Your report will be stored '
              'on this device and synchronized when a '
              'connection becomes available.',
              style: AppTextStyles.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }
}


// ------------------------------------------------------------




















