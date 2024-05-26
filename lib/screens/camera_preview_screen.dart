import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class CameraPreviewScreen extends StatefulWidget {
  final CameraController cameraController;

  const CameraPreviewScreen({Key? key, required this.cameraController})
      : super(key: key);

  @override
  _CameraPreviewScreenState createState() => _CameraPreviewScreenState();
}

class _CameraPreviewScreenState extends State<CameraPreviewScreen> {
  late FaceDetector faceDetector;
  late String instruction;
  bool lookingLeft = false;
  bool lookingRight = false;
  bool lookingUp = false;
  bool lookingDown = false;

  // make sure just send the first image, so not spamming to backend
  bool haveSendImage = false;
  // improve performance and recude face detector in every frame
  int frameCount = 0;
  // Process every 3rd frame
  final int throttleRate = 3;

  @override
  void initState() {
    super.initState();
    faceDetector = GoogleMlKit.vision.faceDetector(FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableContours: true,
      enableTracking: true,
      minFaceSize: 0.2, // Adjust the value based on your preference
      performanceMode: FaceDetectorMode.fast,
    ));
    instruction = 'U R (!human)';
    _initializeCamera();
  }

  void _initializeCamera() async {
    try {
      if (!widget.cameraController.value.isInitialized) {
        await widget.cameraController.initialize();
      }
      await widget.cameraController.startImageStream((CameraImage cameraImage) {
        print('ini adalah camera ${cameraImage.toString()}');
        _processCameraImage(cameraImage);
      });
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    frameCount++;
    if (frameCount % throttleRate != 0) return; // Throttle frame processing
    print('frame ke-$frameCount');


    final int sensorOrientation =
        widget.cameraController.description.sensorOrientation;

    InputImageRotation rotation = InputImageRotation.rotation0deg;
    switch (sensorOrientation) {
      case 90:
        rotation = InputImageRotation.rotation90deg;
        break;
      case 180:
        rotation = InputImageRotation.rotation180deg;
        break;
      case 270:
        rotation = InputImageRotation.rotation270deg;
        break;
      default:
        rotation = InputImageRotation.rotation0deg;
    }

    final InputImageData inputImage = InputImageData(
      imageRotation: rotation,
      inputImageFormat: InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.yuv_420_888,
      size: Size(image.width.toDouble(), image.height.toDouble()),
      planeData: image.planes.map(
        (Plane plane) {
          return InputImagePlaneMetadata(
            bytesPerRow: plane.bytesPerRow,
            height: plane.height,
            width: plane.width,
          );
        },
      ).toList(),
    );

    // for mlkit 13
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    InputImage firebaseVisionImage = InputImage.fromBytes(
      bytes: bytes,
      inputImageData: inputImage,
    );
    // for mlkit 13

    try {
      final List<Face> faces =
          await faceDetector.processImage(firebaseVisionImage);
      if (mounted) {
        setState(() {
          // Handle detected faces here
          print('Detected faces: $faces');

          for (final Face face in faces) {
            checkExpression(face);
          }
        });
      }
    } catch (e) {
      print('Error during face detection: $e');
    }
  }

  void _stopCameraImageStream() async {
    await widget.cameraController.stopImageStream();
    // await widget.cameraController.dispose();
    faceDetector.close();
  }

  void checkExpression(Face face) {
    double? smilingProb = face.smilingProbability ?? 0.0;
    double? rightEyeProb = face.rightEyeOpenProbability ?? 1.0;
    double? leftEyeProb = face.leftEyeOpenProbability ?? 1.0;
    double? headAngleY = face.headEulerAngleY ?? 0.0;
    double? headAngleX = face.headEulerAngleX ?? 0.0;

    Map<String, String> expressions = {
      'smiling': 'The human is smiling!',
      'rightEyeClosed': 'The human\'s right eye is closed!',
      'leftEyeClosed': 'The human\'s left eye is closed!',
      'lookingLeft': 'The human is looking to the left!',
      'lookingRight': 'The human is looking to the right!',
      'lookingUp': 'The human is looking up!',
      'lookingDown': 'The human is looking down!',
      'default': 'Hii, Human!'
    };

    if (smilingProb > 0.5) {
      instruction = expressions['smiling']!;
      if (lookingDown &&
          lookingUp &&
          lookingLeft &&
          lookingRight &&
          !haveSendImage) {
        _takePictureAndSendToAPI();
        haveSendImage = true;
      }
    } else if (rightEyeProb < 0.1) {
      instruction = expressions['rightEyeClosed']!;
    } else if (leftEyeProb < 0.1) {
      instruction = expressions['leftEyeClosed']!;
    } else if (headAngleY > 10) {
      instruction = expressions['lookingLeft']!;
      lookingLeft = true;
    } else if (headAngleY < -10) {
      instruction = expressions['lookingRight']!;
      lookingRight = true;
    } else if (headAngleX > 10) {
      instruction = expressions['lookingUp']!;
      lookingUp = true;
    } else if (headAngleX < -10) {
      instruction = expressions['lookingDown']!;
      lookingDown = true;
    } else {
      instruction = expressions['default']!;
    }

    print(instruction);
  }

  void _takePictureAndSendToAPI() async {
    try {
      XFile? imageFile = await widget.cameraController.takePicture();

      // TODO: Implement API sending logic with the captured image here
      print('the person : Image captured and sent to API: ${imageFile.path}');
    } catch (e) {
      print('Error capturing image or sending to API: $e');
    }
  }

  @override
  void dispose() {
    _stopCameraImageStream();
    // widget.cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.cameraController.value.isInitialized) {
      return Container(); // Or a loading indicator
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: widget.cameraController.value.previewSize!.height,
                height: widget.cameraController.value.previewSize!.width,
                child: CameraPreview(widget.cameraController),
              )),
          Positioned(
              top: 32.0,
              left: 16.0,
              child: FloatingActionButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back))),
          Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                  padding: const EdgeInsets.only(bottom: 32.0),
                  child: ElevatedButton(
                      onPressed: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pets_outlined),
                          const SizedBox(width: 10.0),
                          if (haveSendImage) ...[
                            const Text("Saving Your Photo...")
                          ] else if (!lookingLeft) ...[
                            const Text("Please Look Left")
                          ] else if (!lookingRight) ...[
                            const Text("Please Look Right")
                          ] else if (!lookingUp) ...[
                            const Text("Please Look Up")
                          ] else if (!lookingDown) ...[
                            const Text("Please Look Down")
                          ] else ...[
                            const Text("Please look at camera then smile")
                          ],
                          const SizedBox(width: 10.0),
                          const Icon(Icons.pets_outlined),
                        ],
                      )))),
          Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                  padding: const EdgeInsets.only(bottom: 80.0),
                  child: ElevatedButton(
                      onPressed: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.swipe_left_alt_rounded,
                              color:
                                  (lookingLeft) ? Colors.green : Colors.grey),
                          Icon(Icons.swipe_down_alt_rounded,
                              color:
                                  (lookingDown) ? Colors.green : Colors.grey),
                          Icon(Icons.swipe_up_alt_rounded,
                              color: (lookingUp) ? Colors.green : Colors.grey),
                          Icon(Icons.swipe_right_alt_rounded,
                              color:
                                  (lookingRight) ? Colors.green : Colors.grey),
                        ],
                      )))),
        ],
      ),
    );
  }
}
