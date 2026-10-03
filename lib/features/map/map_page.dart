import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart';
import 'package:flutter_map_vector_tiles_mbtiles/flutter_map_vector_tiles_mbtiles.dart';

import 'services/offline_mbtiles_service.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/hazard_report.dart';
import '../../core/storage/report_storage.dart';
import '../../core/services/risk_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'models/hazard.dart';
import 'models/community_response.dart';
import 'services/offline_map_config.dart';
import 'services/community_response_storage.dart';
import 'services/community_evidence_scorer.dart';
import 'services/community_response_policy.dart';
import 'utils/hazard_location_formatter.dart';
import 'utils/hazard_report_mapper.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

enum _MapLayer { standard, satellite, hybrid }

class _MapPageState extends State<MapPage> {
  final RiskEngine _riskEngine = const RiskEngine();
  final CommunityResponseStorage _communityResponseStorage =
      CommunityResponseStorage();
  bool _offlineMapAvailable = false;
  // ignore: prefer_final_fields
  bool _offlineMapLoading = true;

  Style? _offlineStyle;

  final MapController _mapController = MapController();

  // RMK Engineering College, as placed in the bundled prism_rmkcet.mbtiles.
  // Must stay inside the bundled coverage (13.264-13.540 N, 80.051-80.225 E).
  static const LatLng _defaultCenter = LatLng(13.3568, 80.1423);

  List<Hazard> hazards = [];
  Position? currentPosition;

  bool isLocating = false;
  bool isLoading = true;
  String? locationMessage;

  _MapLayer _selectedLayer = _MapLayer.standard;

  double _currentZoom = 14;

  @override
  void initState() {
    super.initState();

    // Subscribe before the first load so a write that lands while it is
    // running is not missed.
    ReportStorage.changes.addListener(_onReportsChanged);

    _initializeOfflineMap();
    _loadHazards();
    _getCurrentLocation();
  }

  Future<void> _initializeOfflineMap() async {
    try {
      final path = await OfflineMbtilesService.prepare();

      final provider = await MbTilesVectorTileProvider.open(path);

      final style = await StyleReader(
        uri: 'asset://assets/styles/prism_offline_style.json',
        cache: false,
        resolveProvider: (sourceId) async {
          if (sourceId == 'openmaptiles') {
            return provider;
          }
          return null;
        },
      ).read();

      if (!mounted) {
        style.dispose();
        return;
      }

      setState(() {
        _offlineStyle = style;
        _offlineMapAvailable = true;
        _offlineMapLoading = false;
      });
    } catch (e) {
      debugPrint('Offline MBTiles initialization failed: ');

      if (!mounted) return;

      setState(() {
        _offlineMapAvailable = false;
        _offlineMapLoading = false;
      });
    }
  }

  @override
  void dispose() {
    ReportStorage.changes.removeListener(_onReportsChanged);
    _offlineStyle?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation({bool moveMap = true}) async {
    if (!mounted) return;

    setState(() {
      isLocating = true;
      locationMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          isLocating = false;
          locationMessage = 'Location service is turned off.';
        });

        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          isLocating = false;
          locationMessage = 'Location permission was denied.';
        });

        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          isLocating = false;
          locationMessage = 'Location permission is permanently denied.';
        });

        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        currentPosition = position;
        isLocating = false;
        locationMessage = null;
      });

      if (moveMap) {
        _mapController.move(LatLng(position.latitude, position.longitude), 15);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLocating = false;
        locationMessage = 'Unable to determine current location.';
      });
    }
  }

  Future<void> _loadHazards() async {
    final reports = await ReportStorage().getReports();

    final loadedHazards = reports
        .where((report) => report.latitude != null && report.longitude != null)
        .map(_reportToHazard)
        .where((hazard) => hazard.isVisibleOnMap)
        .toList();

    if (!mounted) return;

    setState(() {
      hazards = loadedHazards;
      isLoading = false;
    });
  }

  // Reloads hazards after any successful ReportStorage write so the map does
  // not need a manual refresh. Loading only reads storage, so this cannot
  // trigger itself, and it leaves the location and camera alone.
  void _onReportsChanged() {
    _loadHazards();
  }

  Hazard _reportToHazard(HazardReport report) {
    return mapHazardFromReport(report, _riskEngine);
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    await _loadHazards();
    await _getCurrentLocation(moveMap: false);
  }

  LatLng get _mapCenter {
    if (currentPosition != null) {
      return LatLng(currentPosition!.latitude, currentPosition!.longitude);
    }

    if (hazards.isNotEmpty) {
      return LatLng(hazards.first.latitude, hazards.first.longitude);
    }

    return _defaultCenter;
  }

  List<_HazardCluster> _buildClusters() {
    final clusters = <_HazardCluster>[];

    if (hazards.isEmpty) {
      return clusters;
    }

    final threshold = _clusterDistanceForZoom(_currentZoom);

    for (final hazard in hazards) {
      _HazardCluster? existingCluster;

      for (final cluster in clusters) {
        final distance = _distanceInMeters(
          hazard.latitude,
          hazard.longitude,
          cluster.latitude,
          cluster.longitude,
        );

        if (distance <= threshold) {
          existingCluster = cluster;
          break;
        }
      }

      if (existingCluster == null) {
        clusters.add(
          _HazardCluster(
            latitude: hazard.latitude,
            longitude: hazard.longitude,
            hazards: [hazard],
          ),
        );
      } else {
        existingCluster.hazards.add(hazard);
        existingCluster.recalculateCenter();
      }
    }

    return clusters;
  }

  double _clusterDistanceForZoom(double zoom) {
    if (zoom >= 17) return 15;
    if (zoom >= 16) return 25;
    if (zoom >= 15) return 40;
    if (zoom >= 14) return 70;
    if (zoom >= 13) return 120;
    if (zoom >= 12) return 220;
    return 400;
  }

  double _distanceInMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;

    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;

    final deltaLat = (lat2 - lat1) * math.pi / 180;
    final deltaLon = (lon2 - lon1) * math.pi / 180;

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(currentPosition!.latitude, currentPosition!.longitude),
          width: 42,
          height: 42,
          child: const _CurrentLocationMarker(),
        ),
      );
    }

    final clusters = _buildClusters();

    for (final cluster in clusters) {
      if (cluster.hazards.length == 1) {
        final hazard = cluster.hazards.first;

        markers.add(
          Marker(
            point: LatLng(hazard.latitude, hazard.longitude),
            width: 42,
            height: 42,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _showHazardPreview(hazard);
              },
              child: _HazardMarker(hazard: hazard),
            ),
          ),
        );
      } else {
        markers.add(
          Marker(
            point: LatLng(cluster.latitude, cluster.longitude),
            width: 48,
            height: 48,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _showActiveHazards(
                  selectedHazardId: cluster.hazards.first.id,
                );
              },
              child: _HazardClusterMarker(
                count: cluster.hazards.length,
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  void _showHazardPreview(Hazard hazard) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: false,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _hazardIcon(
                      hazard.type,
                      color: _riskColor(hazard.riskLevel),
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hazard.title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _RiskBadge(riskLevel: hazard.riskLevel),
                const SizedBox(height: 12),
                Text(
                  'Selected severity: '
                  '${hazard.selectedSeverity ?? 'Not specified'}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                Text(
                  hazard.description.isEmpty
                      ? 'No description provided.'
                      : hazard.description,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 10),
                Text(
                  ', '
                  '',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);

                      _mapController.move(
                        LatLng(hazard.latitude, hazard.longitude),
                        17,
                      );

                      _openHazardReport(hazard);
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('VIEW FULL REPORT'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showActiveHazards({String? selectedHazardId}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 10, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'ACTIVE HAZARDS',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (hazards.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('No active hazards available.'),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(14),
                        itemCount: hazards.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final hazard = hazards[index];

                          return _ActiveHazardListItem(
                            hazard: hazard,
                            selected: hazard.id == selectedHazardId,
                            onTap: () {
                              Navigator.pop(context);

                              _mapController.move(
                                LatLng(hazard.latitude, hazard.longitude),
                                17,
                              );

                              _showHazardPreview(hazard);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openHazardReport(Hazard hazard) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _HazardReportDetailsPage(
          hazard: hazard,
          responseStorage: _communityResponseStorage,
          onCommunityResponse: (isPresent) =>
              _recordCommunityResponse(hazard, isPresent),
        ),
      ),
    );
  }

  Future<CommunityResponse?> _recordCommunityResponse(
    Hazard hazard,
    bool isPresent,
  ) async {
    try {
      final cooldownRemaining = await _communityResponseStorage
          .getCooldownRemainingForHazard(
            hazardId: hazard.id,
            referenceTime: DateTime.now(),
          );
      if (cooldownRemaining != null) {
        _showVerificationMessage(
          'You can verify this hazard again in '
          '${_formatCooldownRemaining(cooldownRemaining)}.',
        );
        return null;
      }
    } catch (_) {
      _showVerificationMessage('Unable to check verification cooldown.');
      return null;
    }

    Position position;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showVerificationMessage('Location is required to verify this hazard.');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showVerificationMessage('Location is required to verify this hazard.');
        return null;
      }

      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      _showVerificationMessage('Location is required to verify this hazard.');
      return null;
    }

    if (!mounted) return null;

    final distance = _distanceInMeters(
      position.latitude,
      position.longitude,
      hazard.latitude,
      hazard.longitude,
    );

    if (distance > 100) {
      _showVerificationMessage(
        'You must be within 100 m of this hazard to verify it.',
      );
      return null;
    }

    final index = hazards.indexWhere((item) => item.id == hazard.id);

    if (index == -1) {
      return null;
    }

    final current = hazards[index];
    late final CommunityResponseSubmissionResult submission;

    try {
      submission = await _communityResponseStorage.submitResponse(
        hazardId: hazard.id,
        response: isPresent
            ? CommunityResponseValue.yes
            : CommunityResponseValue.no,
        distanceMeters: distance,
        respondedAt: DateTime.now(),
      );
    } catch (_) {
      _showVerificationMessage('Unable to save verification. Please try again.');
      return null;
    }

    final response = submission.response;
    if (response == null) {
      final cooldownRemaining = submission.cooldownRemaining;
      if (cooldownRemaining != null) {
        _showVerificationMessage(
          'You can verify this hazard again in '
          '${_formatCooldownRemaining(cooldownRemaining)}.',
        );
      }
      return null;
    }

    if (!mounted) return null;

    final activeResponses = submission.activeResponses;
    final yesCount = activeResponses
        .where((item) => item.response == CommunityResponseValue.yes)
        .length;
    final noCount = activeResponses
        .where((item) => item.response == CommunityResponseValue.no)
        .length;
    final latestActiveResponse = activeResponses.reduce(
      (latest, item) =>
          item.respondedAt.isAfter(latest.respondedAt) ? item : latest,
    );

    final updatedHazard = Hazard(
      id: current.id,
      type: current.type,
      status: current.status,
      riskLevel: current.riskLevel,
      riskScore: current.riskScore,
      selectedSeverity: current.selectedSeverity,
      latitude: current.latitude,
      longitude: current.longitude,
      title: current.title,
      description: current.description,
      reportedAt: current.reportedAt,
      verifiedAt: current.verifiedAt,
        confirmationCount: yesCount,
        totalResponses: activeResponses.length,
        yesConfirmations: yesCount,
        noConfirmations: noCount,
        latestResponseAt: latestActiveResponse.respondedAt,
      imagePath: current.imagePath,
    );

    setState(() {
      hazards[index] = updatedHazard;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPresent
              ? 'Thanks! Hazard confirmed.'
              : 'Thanks! Hazard marked as not present.',
        ),
      ),
    );

    return response;
  }

  void _showVerificationMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatCooldownRemaining(Duration remaining) {
    final totalMinutes = (remaining.inSeconds / 60).ceil();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) {
      return '$totalMinutes ${totalMinutes == 1 ? 'minute' : 'minutes'}';
    }
    if (minutes == 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }

    return '$hours hr $minutes min';
  }

  String _tileUrl() {
    switch (_selectedLayer) {
      case _MapLayer.standard:
        return OfflineMapConfig.onlineTileUrl;

      case _MapLayer.satellite:
      case _MapLayer.hybrid:
        return 'https://server.arcgisonline.com/'
            'ArcGIS/rest/services/World_Imagery/'
            'MapServer/tile/{z}/{y}/{x}';
    }
  }

  String _layerName() {
    switch (_selectedLayer) {
      case _MapLayer.standard:
        return 'Standard';

      case _MapLayer.satellite:
        return 'Satellite';

      case _MapLayer.hybrid:
        return 'Hybrid';
    }
  }

  Future<void> _showLayerSelector() async {
    final selected = await showModalBottomSheet<_MapLayer>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MAP TYPE',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                _LayerOption(
                  icon: Icons.map_outlined,
                  title: 'Standard',
                  subtitle: 'Roads, places and normal map view',
                  selected: _selectedLayer == _MapLayer.standard,
                  onTap: () {
                    Navigator.pop(context, _MapLayer.standard);
                  },
                ),
                _LayerOption(
                  icon: Icons.satellite_alt,
                  title: 'Satellite',
                  subtitle: 'Satellite / aerial imagery',
                  selected: _selectedLayer == _MapLayer.satellite,
                  onTap: () {
                    Navigator.pop(context, _MapLayer.satellite);
                  },
                ),
                _LayerOption(
                  icon: Icons.layers_outlined,
                  title: 'Hybrid',
                  subtitle: 'Satellite imagery with map labels',
                  selected: _selectedLayer == _MapLayer.hybrid,
                  onTap: () {
                    Navigator.pop(context, _MapLayer.hybrid);
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Satellite imagery requires Internet access. '
                  'Offline satellite tiles will be supported '
                  'after offline map packs are implemented.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    setState(() {
      _selectedLayer = selected;
    });
  }

  void _showLegend() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HAZARD LEGEND',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                _LegendRow(type: HazardType.openManhole, title: 'Open Manhole'),
                _LegendRow(type: HazardType.floodedRoad, title: 'Flooded Road'),
                _LegendRow(type: HazardType.fallenTree, title: 'Fallen Tree'),
                _LegendRow(
                  type: HazardType.electricHazard,
                  title: 'Electric Hazard',
                ),
                _LegendRow(
                  type: HazardType.damagedRoad,
                  title: 'Damaged Road',
                ),
                _LegendRow(
                  type: HazardType.waterLogging,
                  title: 'Waterlogging',
                ),
                _LegendRow(type: HazardType.other, title: 'Other Hazard'),
                const SizedBox(height: 8),
                const Text(
                  'Nearby hazards are grouped into numbered '
                  'clusters. Tap a marker or cluster to view details.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: 14,
                minZoom: 8,
                maxZoom: _selectedLayer == _MapLayer.standard ? 14 : 18,
                onPositionChanged: (camera, hasGesture) {
                  if (camera.zoom != _currentZoom) {
                    setState(() {
                      _currentZoom = camera.zoom;
                    });
                  }
                },
              ),
              children: [
                if (_selectedLayer == _MapLayer.standard &&
                    _offlineStyle != null)
                  VectorTileLayer(
                    theme: _offlineStyle!.theme,
                    tileProviders: _offlineStyle!.providers,
                    rasterSources: _offlineStyle!.rasterSources,
                    sprites: _offlineStyle!.sprites,
                    showLabels: true,
                  )
                else
                  TileLayer(
                    urlTemplate: _tileUrl(),
                    userAgentPackageName: 'com.prism.floodhazard',
                    minZoom: 0,
                    maxZoom: 18,
                    maxNativeZoom:
                        _selectedLayer == _MapLayer.standard ? 19 : 18,
                    keepBuffer: 2,
                  ),
                if (_selectedLayer == _MapLayer.hybrid)
                  Opacity(
                    opacity: 0.75,
                    child: TileLayer(
                      urlTemplate: OfflineMapConfig.onlineTileUrl,
                      userAgentPackageName: 'com.prism.floodhazard',
                      minZoom: 0,
                      maxZoom: 19,
                      maxNativeZoom: 19,
                      keepBuffer: 2,
                    ),
                  ),
                if (_offlineMapLoading &&
                    _selectedLayer == _MapLayer.standard)
                  Positioned(
                    top: 190,
                    left: 24,
                    right: 24,
                    child: Material(
                      color: Colors.white,
                      elevation: 5,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Preparing offline map...',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                MarkerLayer(markers: _buildMarkers()),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      _selectedLayer == _MapLayer.standard
                          ? 'OpenStreetMap contributors'
                          : 'Esri',
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.white,
                      elevation: 4,
                      borderRadius: BorderRadius.circular(10),
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: 'Search location...',
                          prefixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MapButton(
                    icon: Icons.layers_outlined,
                    tooltip: 'Map layers',
                    onPressed: _showLayerSelector,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 72,
              left: 12,
              child: Material(
                color: Colors.white,
                elevation: 3,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.map, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        _layerName().toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 120,
              child: Column(
                children: [
                  _MapButton(
                    icon: Icons.my_location,
                    tooltip: 'My location',
                    onPressed: isLocating ? null : () => _getCurrentLocation(),
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.refresh,
                    tooltip: 'Refresh hazards',
                    onPressed: _refresh,
                  ),
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.info_outline,
                    tooltip: 'Hazard legend',
                    onPressed: _showLegend,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: Material(
                color: Colors.white,
                elevation: 5,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    _showActiveHazards();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 23),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ' ACTIVE HAZARDS',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Tap to view hazard list',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_offlineMapAvailable)
                          const Icon(Icons.offline_pin, size: 19)
                        else
                          const Icon(Icons.cloud_outlined, size: 19),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 21),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (locationMessage != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 90,
                child: Material(
                  color: Colors.white,
                  elevation: 3,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      locationMessage!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  ),
                ),
              ),
            if (isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

class _HazardCluster {
  double latitude;
  double longitude;

  final List<Hazard> hazards;

  _HazardCluster({
    required this.latitude,
    required this.longitude,
    required this.hazards,
  });

  void recalculateCenter() {
    if (hazards.isEmpty) return;

    latitude =
        hazards.map((hazard) => hazard.latitude).reduce((a, b) => a + b) /
        hazards.length;

    longitude =
        hazards.map((hazard) => hazard.longitude).reduce((a, b) => a + b) /
        hazards.length;
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(9),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _LayerOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _LayerOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: selected
          ? const Icon(Icons.check_circle, size: 22)
          : const Icon(Icons.radio_button_unchecked, size: 22),
      onTap: onTap,
    );
  }
}

class _LegendRow extends StatelessWidget {
  final HazardType type;
  final String title;

  const _LegendRow({required this.type, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          _hazardIcon(type, size: 25),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.withValues(alpha: 0.18),
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    );
  }
}

class _HazardMarker extends StatelessWidget {
  final Hazard hazard;

  const _HazardMarker({required this.hazard});

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(hazard.riskLevel);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: color, width: 2),
          boxShadow: const [
            BoxShadow(
              blurRadius: 3,
              offset: Offset(0, 1),
              color: Colors.black26,
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: _hazardIcon(hazard.type, color: color, size: 21),
      ),
    );
  }
}

class _HazardClusterMarker extends StatelessWidget {
  final int count;

  const _HazardClusterMarker({required this.count});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: AppColors.danger, width: 2),
          boxShadow: const [
            BoxShadow(
              blurRadius: 4,
              offset: Offset(0, 2),
              color: Colors.black26,
            ),
          ],
        ),
        child: Center(
          child: Text(
            '',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class _ActiveHazardListItem extends StatelessWidget {
  final Hazard hazard;
  final bool selected;
  final VoidCallback onTap;

  const _ActiveHazardListItem({
    required this.hazard,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final riskColor = _riskColor(hazard.riskLevel);

    return Material(
      color: selected ? Colors.grey.shade100 : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? riskColor : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: riskColor, width: 1.5),
                ),
                child: Center(
                  child: _hazardIcon(
                    hazard.type,
                    color: riskColor,
                    size: 23,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hazard.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hazard.description.isEmpty
                          ? 'No description'
                          : hazard.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Selected severity: '
                      '${hazard.selectedSeverity ?? 'Not specified'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formatHazardLocation(
                        hazard.latitude,
                        hazard.longitude,
                      ),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _RiskBadge(riskLevel: hazard.riskLevel),
                  const SizedBox(height: 6),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final RiskLevel riskLevel;

  const _RiskBadge({required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(riskLevel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Risk: ${riskLevel.name.toUpperCase()}',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

Widget _hazardIcon(HazardType type, {Color? color, double size = 30}) {
  IconData icon;

  switch (type) {
    case HazardType.openManhole:
      icon = Icons.circle_outlined;
      break;
    case HazardType.floodedRoad:
      icon = Icons.water;
      break;
    case HazardType.fallenTree:
      icon = Icons.park;
      break;
    case HazardType.electricHazard:
      icon = Icons.bolt;
      break;
    case HazardType.damagedRoad:
      icon = Icons.construction;
      break;
    case HazardType.waterLogging:
      icon = Icons.water_drop;
      break;
    case HazardType.other:
      icon = Icons.warning_amber_rounded;
      break;
  }

  return Icon(icon, color: color, size: size);
}

Color _riskColor(RiskLevel risk) {
  switch (risk) {
    case RiskLevel.low:
      return AppColors.information;
    case RiskLevel.moderate:
      return AppColors.warning;
    case RiskLevel.high:
    case RiskLevel.critical:
      return AppColors.danger;
  }
}

class _HazardReportDetailsPage extends StatefulWidget {
  final Hazard hazard;
  final CommunityResponseStorage responseStorage;
  final Future<CommunityResponse?> Function(bool isPresent) onCommunityResponse;

  const _HazardReportDetailsPage({
    required this.hazard,
    required this.responseStorage,
    required this.onCommunityResponse,
  });

  @override
  State<_HazardReportDetailsPage> createState() =>
      _HazardReportDetailsPageState();
}

class _HazardReportDetailsPageState extends State<_HazardReportDetailsPage> {
  List<CommunityResponse> _responses = [];

  Hazard get hazard => widget.hazard;

  List<CommunityResponse> get _activeResponses =>
      latestCommunityResponsesForHazard(_responses, hazard.id);

  CommunityResponse? get _latestResponse {
    final activeResponses = _activeResponses;
    if (activeResponses.isEmpty) return null;

    return activeResponses.reduce(
      (latest, response) =>
          response.respondedAt.isAfter(latest.respondedAt)
          ? response
          : latest,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadResponses();
  }

  Future<void> _loadResponses() async {
    try {
      final responses = await widget.responseStorage.getResponsesForHazard(
        hazard.id,
      );
      if (!mounted) return;
      setState(() {
        _responses = responses;
      });
    } catch (_) {
      // Keep the details screen available if local storage cannot be read.
    }
  }

  Future<void> _submitResponse(bool isPresent) async {
    final response = await widget.onCommunityResponse(isPresent);
    if (response == null || !mounted) return;
    setState(() {
      _responses.add(response);
    });
  }

  String _formatResponseTimestamp(DateTime timestamp) {
    final localTime = timestamp.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = localTime.hour % 12 == 0 ? 12 : localTime.hour % 12;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final period = localTime.hour >= 12 ? 'PM' : 'AM';

    return '${months[localTime.month - 1]} ${localTime.day}, '
        '${localTime.year}, $hour:$minute $period';
  }

  String _formatResponseAge(DateTime timestamp) {
    final age = DateTime.now().difference(timestamp);

    if (age.isNegative || age.inMinutes < 1) {
      return 'just now';
    }
    if (age.inMinutes < 60) {
      return '${age.inMinutes} minutes ago';
    }
    if (age.inHours < 24) {
      return '${age.inHours} hours ago';
    }
    if (age.inHours < 48) {
      return '1 day ago';
    }

    return '${age.inDays} days ago';
  }

  int _countResponsesWithin(Duration window, DateTime referenceTime) {
    return _activeResponses.where((response) {
      final age = referenceTime.difference(response.respondedAt);
      return !age.isNegative && age <= window;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final latestResponse = _latestResponse;
    final now = DateTime.now();
    final communityScore = calculateCommunityEvidenceScore(
      hazardId: hazard.id,
      responses: _responses,
      referenceTime: now,
    );
    final hazardResponses = _activeResponses;
    final yesCount = hazardResponses
      .where((response) => response.response == CommunityResponseValue.yes)
      .length;
    final noCount = hazardResponses
      .where((response) => response.response == CommunityResponseValue.no)
      .length;
    final responseCount = hazardResponses.length;
    final yesPercentage = responseCount == 0
      ? 0
      : (yesCount * 100 / responseCount).round();
    final noPercentage = responseCount == 0
      ? 0
      : (noCount * 100 / responseCount).round();
    final responsesLastHour = _countResponsesWithin(
      const Duration(hours: 1),
      now,
    );
    final responsesLast24Hours = _countResponsesWithin(
      const Duration(hours: 24),
      now,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hazard Report',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Center(
            child: _hazardIcon(
              hazard.type,
              color: _riskColor(hazard.riskLevel),
              size: 58,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              hazard.title.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(child: _RiskBadge(riskLevel: hazard.riskLevel)),
          _InfoCard(
            title: 'SELECTED SEVERITY',
            value: hazard.selectedSeverity ?? 'Not specified',
          ),
          const SizedBox(height: 24),
          _InfoCard(
            title: 'DESCRIPTION',
            value: hazard.description.isEmpty
                ? 'No description provided.'
                : hazard.description,
          ),
          _InfoCard(
            title: 'LOCATION',
            value: formatHazardLocation(hazard.latitude, hazard.longitude),
          ),
          _InfoCard(
            title: 'REPORTED',
            value: _timeAgo(hazard.reportedAt),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMMUNITY EVIDENCE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                Text('Responses: $responseCount'),
                if (responseCount == 0)
                  const Text('Community response ratio: No votes yet')
                else ...[
                  Text('YES: $yesCount ($yesPercentage%)'),
                  Text('NO: $noCount ($noPercentage%)'),
                ],
                Text('Last hour: $responsesLastHour responses'),
                Text('Last 24 hours: $responsesLast24Hours responses'),
                if (communityScore.value == null)
                  Text(
                    'Community evidence score: ${communityScore.label}',
                  )
                else ...[
                  Text(
                    'Community evidence score: '
                    '${communityScore.value!.round()} / 100',
                  ),
                  Text(communityScore.label),
                ],
                Text(
                  'Latest verification: '
                  '${latestResponse == null ? 'No verification yet' : _formatResponseTimestamp(latestResponse.respondedAt)}',
                ),
                Text(
                  'Verification age: '
                  '${latestResponse == null ? 'No community verification' : _formatResponseAge(latestResponse.respondedAt)}',
                ),
                if (_responses.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final response in _responses)
                    Text(
                      '${response.response.name.toUpperCase()} - '
                      '${response.distanceMeters.round()} m - '
                      '${_formatResponseTimestamp(response.respondedAt)}',
                    ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Is this hazard still present?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _submitResponse(true),
                        child: const Text('YES'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _submitResponse(false),
                        child: const Text('NO'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _InfoCard(
            title: 'STATUS',
            value: hazard.lifecycleLabel,
          ),
          if (hazard.imagePath != null && hazard.imagePath!.isNotEmpty)
            const _InfoCard(
              title: 'PHOTO EVIDENCE',
              value: 'Photo evidence is attached to this report.',
            ),
          const SizedBox(height: 20),
          const Text(
            'Safety note: this report represents available '
            'hazard information and should not be treated as '
            'a guarantee of road safety.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final difference = DateTime.now().difference(time);

    if (difference.inMinutes < 60) {
      return ' min ago';
    }

    if (difference.inHours < 24) {
      return ' hr ago';
    }

    return ' days ago';
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;

  const _InfoCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}




