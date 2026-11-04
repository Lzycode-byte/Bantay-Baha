import 'package:bantay_baha/core/locator.dart';
import 'package:bantay_baha/shell_scaffold.dart';
import 'package:bantay_baha/ui/advisories/advisories_view.dart';
import 'package:bantay_baha/ui/home/home_view.dart';
import 'package:bantay_baha/ui/home/home_viewmodel.dart';
import 'package:bantay_baha/ui/map/map_view.dart';
import 'package:bantay_baha/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

GoRouter _goRouter = GoRouter(
  routes: [
    ShellRoute(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeView()),
        GoRoute(
          path: '/advisories',
          builder: (context, state) => const AdvisoriesView(),
        ),
        GoRoute(path: '/map', builder: (context, state) => const MapView()),
      ],
      builder: (context, state, child) => ChangeNotifierProvider<HomeViewModel>(
        create: (_) => getIt<HomeViewModel>()..init(),
        child: ShellScaffold(child: child),
      ),
    ),
  ],
);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bantay Baha',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: _goRouter,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MapLibreMap.preWarm();
  setupLocator();
  runApp(const MyApp());
}
