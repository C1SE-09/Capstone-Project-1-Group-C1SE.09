import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/theme.dart';
import 'package:adark_frontend/features/kindergarten_dashboard/widgets.dart';

class NoAssignmentScreen extends StatelessWidget {
  const NoAssignmentScreen({
    super.key,
    required this.title,
    required this.message,
    required this.onBack,
    this.icon = Icons.info_outline_rounded,
    this.backButtonLabel = 'Đăng xuất',
    this.gardenVoice = false,
  });

  final String title;
  final String message;
  final VoidCallback onBack;
  final IconData icon;
  final String backButtonLabel;
  final bool gardenVoice;

  @override
  Widget build(BuildContext context) {
    if (!gardenVoice) {
      return Scaffold(
        backgroundColor: context.k.canvas,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: context.k.warnTint.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(icon, size: 48, color: context.k.warn),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            height: 1.5,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 220,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.k.brand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(KRadii.control),
                        ),
                        elevation: 0,
                      ),
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      label: Text(
                        backButtonLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return GardenVoiceScope(
      child: Builder(
        builder: (context) {
          final k = context.k;
          return Scaffold(
            backgroundColor: k.canvas,
            body: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 106, 20, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 350),
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          'assets/garden_voice/no_assignment.svg',
                          width: 76,
                          height: 76,
                          semanticsLabel: 'Biểu tượng nhóm lớp',
                        ),
                        const SizedBox(height: 24),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: k.ink,
                            fontSize: 20,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: k.inkSoft,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: 200,
                          height: 48,
                          child: KButton(
                            label: backButtonLabel,
                            onPressed: onBack,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
