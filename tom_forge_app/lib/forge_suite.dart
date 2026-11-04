/// Tom Forge with all of its functionality, as a library an app starts from:
/// Tom Forge's own app is [ForgeSuiteLauncher] with no extensions, and an app
/// built on Forge (Webforge) adds its modules and applications through
/// [ForgeSuiteExtension]s.
///
/// Forge's licence direction holds: this library, like every Forge package,
/// names no Webwork package — a host adds its own.
library;

export 'src/app.dart' show ForgeApp;
export 'src/forge_app_module.dart' show ForgeAppModule;
export 'src/forge_suite.dart';
