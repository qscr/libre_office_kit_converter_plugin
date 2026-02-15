import Flutter
import UIKit

public class LibreOfficeKitConverterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
      LibreOfficeKitApiSetup.setUp(binaryMessenger: registrar.messenger(), api: LibreOfficeKitApiImpl())
  }
}

class LibreOfficeKitApiImpl: LibreOfficeKitApi {
    private let queue = DispatchQueue(label: "LOK", qos: .default)
    
    private var lokWrapper: LOKWrapper? = nil
    
    func initialize(completion: @escaping (Result<Void, any Error>) -> Void) {
        do {
            let frameworkBundle = Bundle(for: LibreOfficeKitApiImpl.self)
            let wrapper = LOKWrapper.init(installPath: frameworkBundle.bundlePath)
            
            guard wrapper != nil else {
                throw LokError.initializationFailed("LOKWrapper returned nil (lok_init_2 failed). installPath=\(frameworkBundle.bundlePath)")
            }
            
            lokWrapper = wrapper
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    private static func makeOutputURL(
        outputFormat: String,
        outputFilePath: String?,
        outputFileName: String?
    ) throws -> URL {
        let fm = FileManager.default

        if let outputFilePath, !outputFilePath.isEmpty {
            return URL(fileURLWithPath: outputFilePath, isDirectory: false)
        }

        if let outputFileName, !outputFileName.isEmpty {
            let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
            return caches.appendingPathComponent("\(outputFileName).\(outputFormat)")
        }

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return tempDir.appendingPathComponent("LibreOfficeConverted_\(UUID().uuidString).\(outputFormat)")
    }
    
    func convert(filePath: String, outputFormat: String, outputFilePath: String?, outputFileName: String?, filterOptions: String?, completion: @escaping (Result<String, any Error>) -> Void) {
        queue.async {
            do {
                guard let wrapper = self.lokWrapper else {
                    throw LokError.notInitialized
                }

                let outURL = try Self.makeOutputURL(
                    outputFormat: outputFormat,
                    outputFilePath: outputFilePath,
                    outputFileName: outputFileName
                )

                guard let resultPath = self.lokWrapper!.convert(
                    filePath,
                    outputPath: outURL.path,
                    outputFormat: outputFormat,
                    filterOptions: filterOptions ?? ""
                ) else {
                    throw LokError.conversionFailed("saveAs failed (returned nil)")
                }

                completion(.success(resultPath))
            } catch {
                completion(.failure(error))
            }
        }
    }
}


enum LokError: LocalizedError {
    case initializationFailed(String)
    case notInitialized
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .initializationFailed(let s): return "LOK init failed: \(s)"
        case .notInitialized: return "LOK is not initialized. Call initialize() first."
        case .conversionFailed(let s): return "Conversion failed: \(s)"
        }
    }
}
