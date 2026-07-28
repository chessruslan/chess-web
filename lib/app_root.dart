import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'ui/app_shell.dart';
import 'ui/board_theme_controller.dart';
import 'services/site_design_controller.dart';

typedef PlayBuilder = Widget Function(
  Key? key,
  BoardThemeController boardTheme,
);

class AppRoot extends StatelessWidget {
  const AppRoot({
    super.key,
    required this.playBuilder,
  });

  final PlayBuilder playBuilder;

  @override
  Widget build(BuildContext context) {
    final boardTheme = BoardThemeController();

    return AnimatedBuilder(
      animation: Listenable.merge([boardTheme, SiteDesignController.instance]),
      builder: (context, _) {
        final design = SiteDesignController.instance.effective;
        final primary = switch (design.buttonsTheme) {
          'Тёплое дерево' => const Color(0xFF9A6844),
          'Светлая' => const Color(0xFF367C9A),
          _ => const Color(0xFF0B7FA5),
        };
        final cs = ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
          surface: const Color(0xFF2A2E35),
        );
        final radius = design.bordersTheme == 'Строгие'
            ? 4.0
            : design.bordersTheme == 'Мягкие'
                ? 18.0
                : 10.0;
        final fontFamily = switch (design.fontTheme) {
          'Roboto' => 'Roboto',
          'Serif' => 'serif',
          'Monospace' => 'monospace',
          _ => null,
        };
        return MaterialApp(
          title: 'Makechess',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const _NoBounceScrollBehavior(),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: cs,
            fontFamily: fontFamily,
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: design.fieldsTheme == 'Светлые'
                  ? const Color(0xFFE8EDF1)
                  : const Color(0xFF22262C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: const BorderSide(color: Color(0xFF3A4048)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: const BorderSide(color: Color(0xFF00CFFF)),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.disabled)
                      ? cs.primary.withValues(alpha: 0.5)
                      : cs.primary;
                }),
                foregroundColor: WidgetStatePropertyAll(cs.onPrimary),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: Colors.transparent),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                elevation: const WidgetStatePropertyAll(0),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.disabled)
                      ? cs.primary.withValues(alpha: 0.5)
                      : cs.primary;
                }),
                foregroundColor: WidgetStatePropertyAll(cs.onPrimary),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                elevation: const WidgetStatePropertyAll(0),
              ),
            ),
          ),
          home: AppShell(
            playBuilder: (key, theme) => playBuilder(key, theme),
          ),
        );
      },
    );
  }
}

class _NoBounceScrollBehavior extends MaterialScrollBehavior {
  const _NoBounceScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
