import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'constants/app_colors.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/post_provider.dart';
import 'providers/community_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/profile_settings_screen.dart';
import 'screens/post/create_post_screen.dart';
import 'screens/post/create_end_post_screen.dart';
import 'screens/post/post_detail_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/community/community_chat_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/profile/follow_list_screen.dart';
import 'screens/profile/community_list_screen.dart';
import 'models/post_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (context) => UserProvider(),
          update: (context, authProvider, userProvider) {
            if (userProvider == null) {
              final newUserProvider = UserProvider();
              newUserProvider.setAuthProvider(authProvider);
              return newUserProvider;
            } else {
              userProvider.setAuthProvider(authProvider);
              return userProvider;
            }
          },
        ),
        ChangeNotifierProvider(create: (context) => PostProvider()),
        ChangeNotifierProvider(create: (context) => CommunityProvider()),
      ],
      child: MaterialApp.router(
        title: 'StartEnd SNS',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'NotoSansJP',
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            centerTitle: true,
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: AppColors.surface,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            type: BottomNavigationBarType.fixed,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        routerConfig: _router,
        builder: (context, child) {
          return GestureDetector(
            onPanUpdate: (details) {
              // 右スワイプでの戻る機能
              if (details.delta.dx > 10 &&
                  details.delta.dx.abs() > details.delta.dy.abs()) {
                try {
                  final router = GoRouter.of(context);
                  if (router.canPop()) {
                    router.pop();
                  }
                } catch (e) {
                  // GoRouterが見つからない場合は何もしない
                  if (kDebugMode) {
                    print('GoRouter not found in context: $e');
                  }
                }
              }
            },
            child: child,
          );
        },
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final authProvider = context.read<AuthProvider>();
    final isAuthenticated = authProvider.isAuthenticated;
    final isOnLoginScreen = state.matchedLocation == '/';

    // 認証済みでログイン画面にいる場合はホームへリダイレクト
    if (isAuthenticated && isOnLoginScreen) {
      return '/home';
    }

    // 未認証でログイン画面以外にいる場合はログイン画面へリダイレクト
    if (!isAuthenticated && !isOnLoginScreen) {
      return '/';
    }

    return null; // リダイレクトなし
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/profile/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return ProfileScreen(userId: userId);
      },
    ),
    GoRoute(
      path: '/profile/settings',
      builder: (context, state) => const ProfileSettingsScreen(),
    ),
    GoRoute(
      path: '/community',
      builder: (context, state) => const CommunityScreen(),
    ),
    GoRoute(
      path: '/community/:id',
      builder: (context, state) {
        final communityId = state.pathParameters['id']!;
        return CommunityChatScreen(communityId: communityId);
      },
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/post/create',
      builder: (context, state) {
        final communityId = state.uri.queryParameters['communityId'];
        return CreatePostScreen(communityId: communityId);
      },
    ),
    GoRoute(
      path: '/create-end-post',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final startPostId = extra?['startPostId'] as String?;
        final startPost = extra?['startPost'];

        if (startPostId == null) {
          return const Scaffold(
            body: Center(child: Text('エラー: 投稿IDが見つかりません')),
          );
        }

        return CreateEndPostScreen(
          startPostId: startPostId,
          startPost: startPost,
        );
      },
    ),
    GoRoute(
      path: '/post/:id',
      builder: (context, state) {
        final postId = state.pathParameters['id']!;
        final post = state.extra as PostModel?;
        return PostDetailScreen(
          postId: postId,
          post: post,
        );
      },
    ),
    GoRoute(
      path: '/follow-list/:userId/:type',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        final typeString = state.pathParameters['type']!;

        final type = typeString == 'followers'
            ? FollowListType.followers
            : FollowListType.following;
        final title = typeString == 'followers' ? 'フォロワー' : 'フォロー中';

        return FollowListScreen(
          userId: userId,
          title: title,
          type: type,
        );
      },
    ),
    GoRoute(
      path: '/community-list/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return CommunityListScreen(
          userId: userId,
          title: 'コミュニティ',
        );
      },
    ),
  ],
);
