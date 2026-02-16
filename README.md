# LibreOfficeKit Converter Plugin

A Flutter plugin that uses **LibreOfficeKit** to convert office documents directly on the device.

It allows you to transform DOC(-X), XLS(-X), PPT(-X) and many other formats into PDF (default) or another supported export format **without external services, without internet, fully offline**.

## What is LibreOfficeKit?

**LibreOfficeKit (LOK)** is the API of **LibreOffice** that can load and export documents programmatically.

This plugin packages **LibreOffice** and exposes **LibreOfficeKit** as a simple Flutter API.

## LibreOffice version

Platform builds are based on the following LibreOffice versions:

- Android → LibreOffice 26.8
- iOS → LibreOffice 24.8

## Features

- Convert documents fully offline
- No Cloud / no upload
- Works with many formats supported by LibreOffice
- Simple API
- Custom export filters supported

## Supported conversions

Anything that LibreOffice itself can open and export.

Common examples:

- DOC / DOCX → PDF
- XLS / XLSX → PDF
- PPT / PPTX → PDF
- ODT / RTF → PDF
- and many more

If LibreOffice can do it on desktop, LOK can do it here.

## Installation

Add the dependency in `pubspec.yaml`.

```yaml
dependencies:
  libre_office_kit_converter_plugin: ^x.y.z
```

## API

### `init()`

Initializes LibreOfficeKit.

Must be called **once** before any conversion.

Internally this boots the LibreOffice runtime, loads fonts, registries and prepares the engine.

```dart
await converter.init();
```

---

### `convert()`

Converts a document into another format.

#### Parameters

| Name             | Required | Description                                |
| ---------------- | -------- | ------------------------------------------ |
| `filePath`       | yes      | Path to input document                     |
| `outputFormat`   | no       | Target format. Default: `pdf`              |
| `outputFilePath` | no       | Full-path for output file                  |
| `outputFileName` | no       | Override file name (but with default path) |
| `filterOptions`  | no       | LibreOffice export filter string           |

#### Returns

Path to the produced file.

## Important drawbacks

### Single document at a time

LibreOfficeKit is **not designed for parallel conversions** in the same process.

If you start multiple conversions simultaneously, for example using `Future.wait()`, the documents will still be processed sequentially.

---

### Application size

LibreOffice is huge.

Expect the final application size to grow by **~600 MB** depending on ABI and packaging strategy.

This is the price for fully offline document rendering.

---

### Startup time

Initialization may take noticeable time because fonts, configuration and registries must be loaded.

It is recommended to call `init()` early.

## TODO / Roadmap

- Ability to replace bundled compiled LibreOffice sources with custom builds
- More detailed error reporting

## When should you use this plugin?

Good if you need:

- offline conversion
- no dependency on cloud services
- maximum format compatibility

Bad if:

- app size is critical
- you need parallel conversions
- you only convert a very small subset of simple formats

## License

LibreOffice core is licensed under MPL
