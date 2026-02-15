import 'package:libre_office_kit_converter_plugin/src/libre_office_kit_api.g.dart';

class LibreOfficeKitConverterPlugin {
  final LibreOfficeKitApi _api = LibreOfficeKitApi();

  /// Initializing LibreOffice
  Future<void> init() => _api.initialize();

  /// Convert any file to another format (PDF by default)
  Future<String> convert({
    required String filePath,
    String outputFormat = 'pdf',
    String? outputFilePath,
    String? outputFileName,
    String? filterOptions,
  }) => _api.convert(
    filePath: filePath,
    filterOptions: filterOptions,
    outputFormat: outputFormat,
    outputFilePath: outputFilePath,
    outputFileName: outputFileName,
  );
}
