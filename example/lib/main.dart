import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:libre_office_kit_converter_plugin/libre_office_kit_converter_plugin.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _libreOfficeKitConverterPlugin = LibreOfficeKitConverterPlugin();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  _libreOfficeKitConverterPlugin.init();
                },
                child: Text("Init"),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  final outputDir = await getApplicationCacheDirectory();
                  final picker = await FilePicker.platform.pickFiles();
                  if (picker != null && picker.isSinglePick) {
                    final file = picker.files.first;
                    if (file.path != null) {
                      final result = await _libreOfficeKitConverterPlugin.convert(
                        filePath: file.path!,
                        outputFilePath:
                            '${outputDir.absolute.path}/converted_new_test.pdf',
                      );
                      OpenFile.open(result);
                    }
                  }
                },
                child: Text("Convert"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
