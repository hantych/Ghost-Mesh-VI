// Conditional import: native BLE on mobile/desktop, no-op stub on web.
export 'bluetooth_service_stub.dart'
    if (dart.library.io) 'bluetooth_service_native.dart';
