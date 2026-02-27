/// 应用程序入口文件
///
/// 负责初始化应用配置、设置全局 Provider (如 AuthProvider)、
/// 配置路由监听 (RouteObserver) 以及启动 Material App。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'api/fishpi_api.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/section_page.dart';
import 'pages/user_profile_page.dart';
import 'pages/chat_room_page.dart';
import 'utils/constants.dart';
import 'utils/app_logger.dart';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志工具
  final logger = AppLogger();
  await logger.init();

  // 捕获 Flutter 框架内的错误
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logger.logError(
      details.exception,
      stackTrace: details.stack,
      context: 'Flutter Framework',
    );
  };

  // 捕获异步错误（Platform 级别）
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.logError(error, stackTrace: stack, context: 'Platform');
    return true;
  };

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _router = GoRouter(
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
          builder: (context, state) => const ChatRoomPage(),
        ),
        GoRoute(
          path: '/follow',
          builder: (context, state) => const SectionPage(title: '关注'),
        ),
        GoRoute(
          path: '/member/:username',
          builder: (context, state) =>
              UserProfilePage(username: state.pathParameters['username'] ?? ''),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isInitialized) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp.router(
      title: 'FishPi Client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
