#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface LOKWrapper : NSObject
- (nullable instancetype)initWithInstallPath:(NSString *)installPath;

- (nullable NSString *)convert:(NSString *)inputPath
                             outputPath:(NSString *)outputPath
                           outputFormat:(NSString *)outputFormat
                          filterOptions:(NSString *)filterOptions;
@end
NS_ASSUME_NONNULL_END
