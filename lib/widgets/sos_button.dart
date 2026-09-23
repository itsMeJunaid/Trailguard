import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../screens/rescue_chat_screen.dart';
import 'pressable.dart';

class SOSButton extends StatelessWidget {
  const SOSButton({super.key});

  Future<void> _openRescue(BuildContext context) async {
    HapticFeedback.heavyImpact();
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const RescueChatScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      label: 'Emergency SOS. Opens Rescue Dispatch.',
      tooltip: 'Open Rescue Dispatch',
      haptic: false, // _openRescue fires a heavier one
      borderRadius: BorderRadius.circular(16),
      background: AppTheme.errorContainer,
      onPressed: () => _openRescue(context),
      onLongPress: () => _openRescue(context),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Emergency SOS',
                      style: AppTheme.h3(color: AppTheme.onErrorContainer)),
                  const SizedBox(height: 2),
                  Text(
                    'Step-by-step first aid, offline',
                    style: AppTheme.body(color: AppTheme.onErrorContainer),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                color: AppTheme.onErrorContainer),
          ],
        ),
      ),
    );
  }
}
