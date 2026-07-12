import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Utility class for file operations, particularly downloading/saving files
/// to public directories with a sharing fallback.
class FileUtils {
  FileUtils._();

  /// Resolves the public Downloads directory for the platform.
  /// On Android, it targets the standard '/storage/emulated/0/Download' path.
  /// On Desktop, it resolves the user's Downloads directory.
  /// On iOS/other platforms, it defaults to the application documents directory.
  static Future<Directory> getDownloadsDirectoryPlatform() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      final dir = await getDownloadsDirectory();
      return dir ?? await getApplicationDocumentsDirectory();
    }
  }

  /// Copies a temporary file to the public Downloads folder.
  /// If copying fails (e.g. Scoped Storage permission rules on Android),
  /// it automatically falls back to opening the standard system Share sheet.
  static Future<void> downloadFile({
    required BuildContext context,
    required File tempFile,
    required String shareText,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final fileName = path.basename(tempFile.path);

    try {
      final downloadsDir = await getDownloadsDirectoryPlatform();
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final targetPath = '${downloadsDir.path}/$fileName';
      final targetFile = File(targetPath);

      // Copy the file from temp directory to the public Downloads folder
      await tempFile.copy(targetFile.path);

      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Downloaded to ${targetFile.path}')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Fallback: Share the file using the system dialog
      try {
        if (context.mounted) {
          await Share.shareXFiles(
            [XFile(tempFile.path)],
            text: shareText,
          );
        }
      } catch (shareError) {
        if (context.mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Failed to download or share: $shareError'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }
}
