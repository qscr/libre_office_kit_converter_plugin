import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/libre_office_kit_api.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/example/libre_office_kit_converter_plugin/LibreOfficeKitApi.g.kt',
    swiftOut: 'ios/Classes/LibreOfficeKitApi.g.swift',
    dartPackageName: 'libre_office_kit_converter_plugin',
  ),
)
@HostApi()
abstract class LibreOfficeKitApi {
  /// Initializing LibreOffice
  @async
  void initialize();

  /// Convert any file to another format (PDF by default)
  @async
  String convert({
    required String filePath,
    String outputFormat = 'pdf',
    required String? outputFilePath,
    required String? outputFileName,
    required String? filterOptions,
  });
}
