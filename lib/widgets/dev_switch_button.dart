import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

/// DEV ONLY: jumps to another dashboard with one tap.
/// Renders nothing in release builds.
class DevSwitchButton extends StatelessWidget {
  final String targetRoute;
  final String label;

  const DevSwitchButton({
    super.key,
    required this.targetRoute,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FloatingActionButton.small(
        heroTag: 'devSwitch',
        tooltip: label,
        backgroundColor: Colors.grey.shade300,
        foregroundColor: Colors.black87,
        onPressed: () => Navigator.pushReplacementNamed(context, targetRoute),
        child: const Icon(Icons.swap_horiz),
      ),
    );
  }
}