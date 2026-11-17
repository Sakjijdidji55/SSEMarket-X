import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sse_market_x/core/api/api_service.dart';
import 'package:sse_market_x/core/services/storage_service.dart';
import 'package:sse_market_x/core/app_navigator.dart';
import 'package:sse_market_x/views/auth/login_page.dart';
import 'package:sse_market_x/views/index_page.dart';
import 'package:sse_market_x/views/post/post_detail_page.dart';
import 'package:sse_market_x/views/home/annual_report_page.dart';
import 'package:sse_market_x/views/course/course_page.dart';
import 'package:sse_market_x/views/media/media_hub_page.dart';
import 'package:sse_market_x/views/novel/novel_home_page.dart';
import 'package:sse_market_x/views/resume/resume_list_page.dart';
import 'package:sse_market_x/views/rank/ranking_page.dart';

final GoRouter appRouter = GoRouter(
  navigatorKey: appNavigatorKey,
  initialLocation: '/',
  refreshListenable: StorageService().userNotifier,
  redirect: (BuildContext context, GoRouterState state) {
    final bool isLoggedIn = StorageService().isLoggedIn;
    final bool isLoggingIn = state.matchedLocation == '/login';

    if (!isLoggedIn) {
      // Allow access to login page
      if (isLoggingIn) return null;

      // Redirect to login page for other routes, saving connection
      // We use uri.toString() to capture query params as well
      return '/login?redirect=${Uri.encodeComponent(state.uri.toString())}';
    }

    // If logged in and trying to access login, redirect to home or previous page
    if (isLoggingIn) {
      // Check if there is a redirect param
      final redirect = state.uri.queryParameters['redirect'];
      if (redirect != null && redirect.isNotEmpty) {
        return redirect;
      }
      return '/';
    }

    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginPage();
      },
    ),
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return IndexPage(apiService: ApiService());
      },
    ),
    GoRoute(
      path: '/new',
      redirect: (BuildContext context, GoRouterState state) => '/',
    ),
    GoRoute(
      path: '/new/postdetail/:id',
      redirect: (BuildContext context, GoRouterState state) {
        final id = state.pathParameters['id'];
        return id == null ? '/' : '/postdetail/$id';
      },
    ),
    GoRoute(
      path: '/postdetail/:id',
      builder: (BuildContext context, GoRouterState state) {
        final idStr = state.pathParameters['id'];
        final int? id = int.tryParse(idStr ?? '');
        if (id == null) {
          // Handle invalid ID, redirect to home
          return IndexPage(apiService: ApiService());
        }
        return PostDetailPage(
          postId: id,
          apiService: ApiService(),
        );
      },
    ),
    GoRoute(
      path: '/annual-report',
      builder: (BuildContext context, GoRouterState state) {
        return const AnnualReportPage();
      },
    ),
    GoRoute(
      path: '/ranking',
      builder: (BuildContext context, GoRouterState state) {
        return RankingPage(apiService: ApiService());
      },
    ),
    GoRoute(
      path: '/media',
      builder: (BuildContext context, GoRouterState state) {
        return MediaHubPage(apiService: ApiService());
      },
    ),
    GoRoute(
      path: '/novel',
      builder: (BuildContext context, GoRouterState state) {
        return NovelHomePage(apiService: ApiService());
      },
    ),
    GoRoute(
      path: '/resume',
      builder: (BuildContext context, GoRouterState state) {
        return ResumeListPage(apiService: ApiService());
      },
    ),
    GoRoute(
      path: '/course',
      builder: (BuildContext context, GoRouterState state) {
        return CoursePage(apiService: ApiService());
      },
    ),
  ],
);
