import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'api/fishpi_api.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/section_page.dart';
import 'utils/constants.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ProxyProvider<AuthProvider, FishPiApi>(
          update: (_, auth, __) => auth.api,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final router = GoRouter(
      initialLocation: '/',
      refreshListenable: auth,
      observers: [routeObserver],
      redirect: (context, state) {
        final loggedIn = auth.isLoggedIn;
        final loggingIn = state.matchedLocation == '/login';
        if (!loggedIn) {
          return loggingIn ? null : '/login';
        }
        if (loggingIn) {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/hot',
          builder: (context, state) => const SectionPage(title: '热门'),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) => const SectionPage(title: '聊天室'),
        ),
        GoRoute(
          path: '/follow',
          builder: (context, state) => const SectionPage(title: '关注'),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'FishPi Client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
