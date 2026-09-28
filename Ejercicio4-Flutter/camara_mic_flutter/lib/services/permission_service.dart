import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Solicitud de permisos con mensajes claros en ambas plataformas.
class PermissionService {
  /// Pide el permiso; si fue denegado permanentemente ofrece abrir Ajustes.
  static Future<bool> ensure(BuildContext context, Permission permission, String reason) async {
    var status = await permission.status;
    if (status.isGranted || status.isLimited) return true;
    status = await permission.request();
    if (status.isGranted || status.isLimited) return true;

    if (!context.mounted) return false;
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_outline),
        title: const Text('Permiso necesario'),
        content: Text(status.isPermanentlyDenied
            ? '$reason\n\nEl permiso fue denegado. Actívalo desde los ajustes del sistema.'
            : reason),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
          if (status.isPermanentlyDenied)
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abrir ajustes')),
        ],
      ),
    );
    if (openSettings == true) await openAppSettings();
    return false;
  }
}
