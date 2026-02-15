#import "LOKWrapper.h"
#include "LibreOfficeKit/LibreOfficeKitInit.h"
#include "LibreOfficeKit/LibreOfficeKit.h"

extern "C" {
#import <native-code.h>
}

@interface LOKWrapper () {
    LibreOfficeKit *_office;
    LibreOfficeKitDocument *_doc;
}
@end

@implementation LOKWrapper

- (instancetype)initWithInstallPath:(NSString *)installPath
{
    self = [super init];
    if (!self) return nil;

    const char *install = installPath.UTF8String;
    _office = lok_init_2(install, nullptr);

    if (!_office) return nil;
    _doc = NULL;
    return self;
}


- (NSString *)convert:(NSString *)inputPath
                    outputPath:(NSString *)outputPath
                  outputFormat:(NSString *)outputFormat
                 filterOptions:(NSString *)filterOptions
{
    if (!_office) return nil;

    if (_doc) {
        _doc->pClass->destroy(_doc);
        _doc = NULL;
    }

    _doc = _office->pClass->documentLoad(_office, inputPath.UTF8String);
    if (!_doc) return nil;

    const char *fmt = outputFormat.UTF8String;
    const char *opts = filterOptions.UTF8String;

    _doc->pClass->saveAs(_doc, outputPath.UTF8String, fmt, opts);

    _doc->pClass->destroy(_doc);
    _doc = NULL;

    return outputPath;
}

@end
