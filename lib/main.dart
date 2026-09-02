import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'presentation/bloc/home/home_bloc.dart';
import 'presentation/bloc/player/player_bloc.dart';
import 'presentation/pages/home_page.dart';
import 'utils/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final homeBloc = HomeBloc();
  final playerBloc = PlayerBloc();

  runApp(MetabeetApp(bloc: homeBloc, playerBloc: playerBloc));
}

class MetabeetApp extends StatelessWidget {
  const MetabeetApp({
    super.key,
    required this.bloc,
    required this.playerBloc,
  });

  final HomeBloc bloc;
  final PlayerBloc playerBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeBloc>.value(
      value: bloc,
      child: BlocProvider<PlayerBloc>.value(
        value: playerBloc,
        child: MaterialApp(
          title: 'Metabeet',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: ThemeMode.dark,
          home: const HomePage(),
        ),
      ),
    );
  }
}

/// Windows 11 inspired theme: cool Mica surfaces, crisp 1px borders, Segoe UI
/// typography and rounded Fluent controls, with the beet accent on accent roles.
ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: brightness,
  ).copyWith(
    surfaceTint: Colors.transparent,
    primary: isDark ? AppColors.accentSoft : AppColors.accent,
    surface: isDark ? AppColors.surface : const Color(0xFFF6F6F4),
    onSurface: isDark ? AppColors.onSurface : const Color(0xFF1E1E1E),
    onSurfaceVariant:
        isDark ? AppColors.onSurfaceVariant : const Color(0xFF5A5A57),
    surfaceContainerLowest:
        isDark ? AppColors.surfaceContainerLowest : const Color(0xFFFFFFFF),
    surfaceContainerLow:
        isDark ? AppColors.surfaceContainerLow : const Color(0xFFF0F0EE),
    surfaceContainer:
        isDark ? AppColors.surfaceContainer : const Color(0xFFECECEA),
    surfaceContainerHigh:
        isDark ? AppColors.surfaceContainerHigh : const Color(0xFFE4E4E2),
    surfaceContainerHighest:
        isDark ? AppColors.surfaceContainerHighest : const Color(0xFFDBDBD8),
    surfaceDim: isDark ? AppColors.surfaceDim : const Color(0xFFE6E6E4),
    surfaceBright: isDark ? AppColors.surfaceBright : const Color(0xFFF9F9F7),
    outline: isDark ? AppColors.outline : const Color(0xFF6E747C),
    outlineVariant: isDark ? AppColors.outlineVariant : const Color(0xFFC6C7C9),
    shadow: const Color(0x66000000),
    scrim: const Color(0x99000000),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Segoe UI',
  );

  // Fluent-style button shapes.
  const radius = Radius.circular(5);

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.7),
      thickness: 1,
      space: 1,
    ),
    // Rounded, subtle-bordered FilledButton (primary action).
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.primary),
        foregroundColor: WidgetStatePropertyAll(_contrastText(scheme.primary)),
        shape: WidgetStatePropertyAll(const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(5)),
        )),
        padding:
            WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
        textStyle: WidgetStatePropertyAll(base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        )),
        overlayColor: WidgetStatePropertyAll(
          Colors.white.withValues(alpha: 0.12),
        ),
      ),
    ),
    // Ghost / outlined button.
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
        shape: WidgetStatePropertyAll(const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(radius),
        )),
        overlayColor: WidgetStatePropertyAll(
          scheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(
          BorderSide(color: scheme.outlineVariant),
        ),
        shape: WidgetStatePropertyAll(const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(5)),
        )),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
    ),
    // Subtle window-style dialog.
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      contentTextStyle: TextStyle(color: scheme.onSurface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      selectedColor: scheme.primary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
  );
}

Color _contrastText(Color background) {
  final hsl = HSLColor.fromColor(background);
  return hsl.lightness > 0.6 ? const Color(0xFF1E1E1E) : Colors.white;
}
