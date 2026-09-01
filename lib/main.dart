import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'presentation/bloc/home/home_bloc.dart';
import 'presentation/pages/home_page.dart';
import 'utils/app_colors.dart';

void main() {
  final homeBloc = HomeBloc();

  runApp(MetabeetApp(bloc: homeBloc));
}

class MetabeetApp extends StatelessWidget {
  const MetabeetApp({super.key, required this.bloc});

  final HomeBloc bloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeBloc>.value(
      value: bloc,
      child: MaterialApp(
        title: 'Metabeet',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.dark,
        home: const HomePage(),
      ),
    );
  }
}

/// Dark gray theme with a beet accent used only on accent roles.
ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: brightness,
  ).copyWith(
    surfaceTint: Colors.transparent,
    surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
    onSurface: isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface,
    onSurfaceVariant: isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant,
    surfaceContainerLowest: isDark
        ? AppColors.darkSurfaceContainerLowest
        : AppColors.lightSurfaceContainerLowest,
    surfaceContainerLow: isDark
        ? AppColors.darkSurfaceContainerLow
        : AppColors.lightSurfaceContainerLow,
    surfaceContainer: isDark
        ? AppColors.darkSurfaceContainer
        : AppColors.lightSurfaceContainer,
    surfaceContainerHigh: isDark
        ? AppColors.darkSurfaceContainerHigh
        : AppColors.lightSurfaceContainerHigh,
    surfaceContainerHighest: isDark
        ? AppColors.darkSurfaceContainerHighest
        : AppColors.lightSurfaceContainerHighest,
    surfaceDim: isDark ? AppColors.darkSurfaceDim : AppColors.lightSurfaceDim,
    surfaceBright:
        isDark ? AppColors.darkSurfaceBright : AppColors.lightSurfaceBright,
    outline: isDark ? AppColors.darkOutline : AppColors.lightOutline,
    outlineVariant:
        isDark ? AppColors.darkOutlineVariant : AppColors.lightOutlineVariant,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor:
        isDark ? AppColors.darkSurface : AppColors.lightSurface,
  );
}
