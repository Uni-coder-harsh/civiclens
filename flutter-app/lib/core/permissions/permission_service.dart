import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';

/// Result of a permission request.
enum PermissionResult { granted, denied, permanentlyDenied }

/// Unified permission handling wrapper for Camera, Location, and Storage.
class PermissionService {
  /// Requests Camera + Fine Location + Storage permissions in a single call.
  /// Returns [PermissionResult.granted] only when all required permissions are granted.
  Future<PermissionResult> requestCapturePermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.locationWhenInUse,
    ].request();

    final isPermanentlyDenied =
        statuses.values.any((s) => s == PermissionStatus.permanentlyDenied);

    if (isPermanentlyDenied) return PermissionResult.permanentlyDenied;

    final allGranted =
        statuses.values.every((s) => s == PermissionStatus.granted);

    return allGranted ? PermissionResult.granted : PermissionResult.denied;
  }

  /// Returns [true] if camera and fine location are currently granted.
  Future<bool> hasCapturePermissions() async {
    final camera = await Permission.camera.status;
    final location = await Permission.locationWhenInUse.status;
    return camera.isGranted && location.isGranted;
  }

  /// Shows a dialog guiding the user to open app settings to grant permissions.
  /// Must be called with a valid [BuildContext].
  Future<void> showPermissionDeniedDialog(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Permissions Required',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'CivicLens needs Camera and Location access to capture provable reports.\n\n'
          'Please enable these permissions in your device settings.',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFF94A3B8),
            fontFamily: 'Inter',
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF64748B), fontFamily: 'Inter'),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AppSettings.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Open Settings',
              style:
                  TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
