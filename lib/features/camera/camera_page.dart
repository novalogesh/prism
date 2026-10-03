import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_spacing.dart';

class PrismCameraPage extends StatefulWidget {
  const PrismCameraPage({super.key});

  @override
  State<PrismCameraPage> createState() => _PrismCameraPageState();
}

class _PrismCameraPageState extends State<PrismCameraPage> {
  CameraController? _controller;
  bool _initializing = true;
  bool _takingPicture = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('No camera was found on this device.');
      }

      CameraDescription selectedCamera = cameras.first;

      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          selectedCamera = camera;
          break;
        }
      }

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
        _error = e.toString();
      });
    }
  }

  Future<Position?> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return null;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _takePicture() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _takingPicture) {
      return null;
    }

    setState(() {
      _takingPicture = true;
    });

    try {
      final capturedAt = DateTime.now();
      final photo = await controller.takePicture();
      final position = await _getLocation();

      if (!mounted) return null;

      final selectedPhoto = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => PhotoPreviewPage(
            photoPath: photo.path,
            capturedAt: capturedAt,
            position: position,
          ),
        ),
      );

      if (!mounted || selectedPhoto == null) {
        return null;
      }

      Navigator.of(context).pop(selectedPhoto);
      return selectedPhoto;
    } catch (e) {
      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not take photo: $e'),
        ),
      );

      return null;
    } finally {
      if (mounted) {
        setState(() {
          _takingPicture = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRISM',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'Document Hazard',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildCameraControls(),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'CAMERA UNAVAILABLE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _initializeCamera,
                child: const Text('TRY AGAIN'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera is not ready.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: CameraPreview(controller),
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 260,
              height: 340,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white70,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black54,
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Capture the hazard clearly. '
                    'Location and time will be attached '
                    'to this report.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraControls() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(
        24,
        14,
        24,
        24,
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 28,
              ),
            ),
            GestureDetector(
              onTap: _takingPicture ? null : _takePicture,
              child: Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: _takingPicture
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(
              width: 48,
              height: 48,
            ),
          ],
        ),
      ),
    );
  }
}

class PhotoPreviewPage extends StatelessWidget {
  final String photoPath;
  final DateTime capturedAt;
  final Position? position;

  const PhotoPreviewPage({
    super.key,
    required this.photoPath,
    required this.capturedAt,
    required this.position,
  });

  String _two(int value) {
    return value.toString().padLeft(2, '0');
  }

  String get _date {
    return '${_two(capturedAt.day)}/'
        '${_two(capturedAt.month)}/'
        '${capturedAt.year}';
  }

  String get _time {
    final hour = capturedAt.hour % 12 == 0
        ? 12
        : capturedAt.hour % 12;

    final period =
        capturedAt.hour >= 12 ? 'PM' : 'AM';

    return '${_two(hour)}:'
        '${_two(capturedAt.minute)} '
        '$period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'PHOTO EVIDENCE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder(
              future: XFile(photoPath).readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Text(
                      'Unable to preview photo.',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Image.memory(
                        snapshot.data!,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white38,
                          ),
                        ),
                        child: Column(
                          children: [
                            _infoRow(
                              Icons.calendar_today_outlined,
                              'DATE',
                              _date,
                            ),
                            const SizedBox(height: 12),
                            _infoRow(
                              Icons.access_time,
                              'TIME',
                              _time,
                            ),
                            const SizedBox(height: 12),
                            _infoRow(
                              Icons.location_on_outlined,
                              'LOCATION',
                              position == null
                                  ? 'GPS unavailable'
                                  : '${position!.latitude.toStringAsFixed(6)}, '
                                    '${position!.longitude.toStringAsFixed(6)}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('RETAKE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(photoPath);
                      },
                      child: const Text('USE PHOTO'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Colors.white70,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}




