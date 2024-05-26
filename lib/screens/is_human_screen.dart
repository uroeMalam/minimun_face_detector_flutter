import 'package:flutter/material.dart';
import 'package:minimun_face_detector_flutter/screens/camera_preview_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';

class IsHumanScreen extends StatefulWidget {
  const IsHumanScreen({Key? key}) : super(key: key);

  @override
  _IsHumanScreenState createState() => _IsHumanScreenState();
}

class _IsHumanScreenState extends State<IsHumanScreen> {
  late CameraController _controller;
  late bool _cameraPermissionGranted;

  @override
  void initState() {
    super.initState();
    _cameraPermissionGranted = false;
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    _controller = CameraController(frontCamera, ResolutionPreset.max);
    // await _controller.initialize();
    setState(() {});
  }

  Future<void> _onButtonPressed() async {
    var cameraStatus = await Permission.camera.status;
    setState(() {
      _cameraPermissionGranted = cameraStatus.isGranted;
    });

    if (!cameraStatus.isGranted) {
      cameraStatus = await Permission.camera.request();
    }

    if (_cameraPermissionGranted) {
      _initializeCamera();
      _navigateToCameraPreview();
    } else {
      print('Permissions not granted');
    }
  }

  void _navigateToCameraPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CameraPreviewScreen(cameraController: _controller),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minumum Face Detector Flutter'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _onButtonPressed,
          child: const Text('Open Camera'),
        ),
      ),
    );
  }
}
