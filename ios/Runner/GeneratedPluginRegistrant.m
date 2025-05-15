//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<sqflite_darwin/SqflitePlugin.h>)
#import <sqflite_darwin/SqflitePlugin.h>
#else
@import sqflite_darwin;
#endif

#if __has_include(<sunmi_printer_plus/SunmiPrinterPlusPlugin.h>)
#import <sunmi_printer_plus/SunmiPrinterPlusPlugin.h>
#else
@import sunmi_printer_plus;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [SqflitePlugin registerWithRegistrar:[registry registrarForPlugin:@"SqflitePlugin"]];
  [SunmiPrinterPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"SunmiPrinterPlusPlugin"]];
}

@end
