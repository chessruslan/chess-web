import 'package:flutter/material.dart';

import '../../localization/makechess_localization.dart';

class ElectronicBoardCameraView extends StatelessWidget {
  const ElectronicBoardCameraView({
    super.key,
    required this.active,
    required this.onRunningChanged,
    required this.onStatusChanged,
    required this.onFailed,
    required this.onAspectRatioChanged,
  });

  final bool active;
  final ValueChanged<bool> onRunningChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onFailed;
  final ValueChanged<double?> onAspectRatioChanged;

  @override
  Widget build(BuildContext context) {
    if (active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onAspectRatioChanged(null);
        onRunningChanged(false);
        onStatusChanged('Камера доступна в веб-версии сайта.');
        onFailed();
      });
    }
    return Container(
      color: const Color(0xFF050708),
      alignment: Alignment.center,
      child: MakeChessLocalizedText(
        'Камера доступна в веб-версии сайта.',
        style: const TextStyle(color: Colors.white38),
      ),
    );
  }
}
