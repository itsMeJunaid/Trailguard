import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../screens/rescue_chat_screen.dart';

class SOSButton extends StatelessWidget {
  const SOSButton({super.key});

  Future<void> _openRescue(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const RescueChatScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _openRescue(context),
      onDoubleTap: () => _openRescue(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.errorContainer,
          borderRadius: BorderRadius.circular(24),
        ),
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
                  Text('EMERGENCY SOS',
                      style:
                          AppTheme.h3(color: AppTheme.onErrorContainer)),
                  const SizedBox(height: 2),
                  Text(
                    'Long-press — opens Rescue Dispatch simulation',
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
