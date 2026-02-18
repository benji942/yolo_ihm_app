import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/yolo.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

void main() => runApp(YOLODemo());

class YOLODemo extends StatefulWidget {
  @override
  _YOLODemoState createState() => _YOLODemoState();
}

class _YOLODemoState extends State<YOLODemo> {
  YOLO? yolo11;
  YOLO? yolo12;
  File? selectedImage;
  List<dynamic> results = [];
  bool isLoading = false;
  YoloVersion _selectedModel = YoloVersion.yolo11;

  @override
  void initState() {
    super.initState();
    loadYOLO();
  }

  Future<void> loadYOLO() async {
    setState(() => isLoading = true);

    yolo11 = YOLO(
      modelPath: 'yolo11n',
      task: YOLOTask.detect,
      useMultiInstance: true,
    );

    yolo12 = YOLO(
      modelPath: 'yolo12n',
      task: YOLOTask.detect,
      useMultiInstance: true,
    );

    await yolo11!.loadModel();
    await yolo12!.loadModel();
    setState(() => isLoading = false);
  }

  Future<void> pickAndDetect() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
        isLoading = true;
      });

      final imageBytes = await selectedImage!.readAsBytes();
      final detectionResults = _selectedModel == YoloVersion.yolo12
          ? await yolo12!.predict(imageBytes)
          : await yolo11!.predict(imageBytes);

      setState(() {
        results = detectionResults['boxes'] ?? [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: Text('YOLO IHM')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selectedImage != null)
                Container(height: 300, child: Image.file(selectedImage!)),

              SizedBox(height: 20),

              if (isLoading)
                CircularProgressIndicator()
              else
                Text('Detected ${results.length} objects'),

              SizedBox(height: 20),

              ModelSelector(
                currentVersion: _selectedModel,
                onChanged: (YoloVersion newVersion) {
                  setState(() {
                    _selectedModel = newVersion;
                  });
                  // TODO: Trigger your logic to swap the TensorFlow Lite/ONNX model here
                  print('Switched to: ${newVersion.name}');
                },
              ),

              ElevatedButton(
                onPressed: (yolo11 != null && yolo12 != null)
                    ? pickAndDetect
                    : null,
                child: Text('Pick Image & Detect'),
              ),

              SizedBox(height: 20),

              // Show detection results
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final detection = results[index];
                    return ListTile(
                      title: Text(detection['class'] ?? 'Unknown'),
                      subtitle: Text(
                        'Confidence: ${(detection['confidence'] * 100).toStringAsFixed(1)}%',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 1. Define an Enum for type safety
enum YoloVersion { yolo11, yolo12 }

class ModelSelector extends StatefulWidget {
  final YoloVersion currentVersion;
  final ValueChanged<YoloVersion> onChanged;

  const ModelSelector({
    super.key,
    required this.currentVersion,
    required this.onChanged,
  });

  @override
  State<ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<ModelSelector> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Optional: Label text for accessibility and clarity
        Text('Inference Model', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),

        // 2. The Material 3 Segmented Button
        SegmentedButton<YoloVersion>(
          // Making the set specific ensures only one can be selected
          multiSelectionEnabled: false,

          // Defines the available options
          segments: const <ButtonSegment<YoloVersion>>[
            ButtonSegment<YoloVersion>(
              value: YoloVersion.yolo11,
              label: Text('YOLO11'),
              icon: Icon(Icons.history), // Optional: indicates previous gen
              tooltip: 'Use YOLO v11 model',
            ),
            ButtonSegment<YoloVersion>(
              value: YoloVersion.yolo12,
              label: Text('YOLO12'),
              icon: Icon(Icons.bolt), // Optional: indicates speed/newness
              tooltip: 'Use YOLO v12 model',
            ),
          ],

          // 3. Connects the state
          selected: <YoloVersion>{widget.currentVersion},

          // 4. Handle the state change
          onSelectionChanged: (Set<YoloVersion> newSelection) {
            // fast_immutable_collections or standard logic:
            // Since multiSelectionEnabled is false, the set will always have 1 item.
            widget.onChanged(newSelection.first);
          },

          // Optional: Customize style to fit your branding
          style: ButtonStyle(
            visualDensity: VisualDensity.comfortable,
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
