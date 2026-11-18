import '../domain/repositories/browser_account_import.dart';
import 'browser_import_stub.dart'
    if (dart.library.js_interop) 'browser_import_web.dart'
    as platform;

BrowserAccountImport createBrowserAccountImport() => platform.BrowserImport();
