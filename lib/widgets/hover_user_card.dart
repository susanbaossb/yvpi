/// 悬浮用户卡片容器组件
///
/// 封装了鼠标悬停交互逻辑：
/// - 当鼠标悬停在子组件（通常是头像）上时，显示详细用户信息卡片 (UserInfoCard)。
/// - 处理显示/隐藏的防抖延迟。
/// - 监听路由变化，在页面跳转时自动隐藏悬浮卡片。
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import 'user_info_card.dart';
import '../utils/constants.dart';

class HoverUserCard extends StatefulWidget {
  final Widget child;
  final String userName;
  final String avatarUrl;

  const HoverUserCard({
    super.key,
    required this.child,
    required this.userName,
    required this.avatarUrl,
  });

  @override
  State<HoverUserCard> createState() => _HoverUserCardState();
}

class _HoverUserCardState extends State<HoverUserCard> with RouteAware {
  OverlayEntry? _overlayEntry;
  Timer? _hideTimer;
  User? _cachedUser;
  bool _isLoading = false;

  // Static variable to track the currently showing overlay
  static OverlayEntry? _currentOverlayEntry;
  static _HoverUserCardState? _currentHoverState;

  Timer? _showTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (_overlayEntry != null && _overlayEntry == _currentOverlayEntry) {
      _removeCurrentOverlay();
    } else if (_overlayEntry?.mounted == true) {
      _overlayEntry?.remove();
    }
    super.dispose();
  }

  @override
  void didPushNext() {
    // When a new route is pushed on top of this one
    _hideTimer?.cancel();
    _showTimer?.cancel();
    if (_overlayEntry != null && _overlayEntry == _currentOverlayEntry) {
      _removeCurrentOverlay();
    }
  }

  @override
  void deactivate() {
    _hideTimer?.cancel();
    _showTimer?.cancel();
    if (_overlayEntry != null && _overlayEntry == _currentOverlayEntry) {
      _removeCurrentOverlay();
    }
    super.deactivate();
  }

  static void _removeCurrentOverlay() {
    try {
      if (_currentOverlayEntry?.mounted == true) {
        _currentOverlayEntry?.remove();
      }
    } catch (e) {
      // Ignore error if entry is already disposed
      debugPrint('Error removing overlay: $e');
    }
    _currentOverlayEntry = null;
    _currentHoverState?._overlayEntry = null;
    _currentHoverState = null;
  }

  void _scheduleShowOverlay() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: 300), _showOverlay);
  }

  void _showOverlay() {
    _showTimer?.cancel();
    _hideTimer?.cancel();

    // Safety check: if unmounted, don't show overlay
    if (!mounted) return;

    // Check if the route is the top-most route
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    // If there's another card showing, remove it first
    if (_currentOverlayEntry != null && _currentOverlayEntry != _overlayEntry) {
      // If it's a different card, force close the previous one
      _currentHoverState?._hideTimer?.cancel();
      _removeCurrentOverlay();
    }

    if (_overlayEntry != null) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    // Card width is 320
    const cardWidth = 320.0;

    // Default to right side
    double left = offset.dx + size.width + 10;

    // If it overflows right screen edge, show on left side
    if (left + cardWidth > screenSize.width) {
      left = offset.dx - cardWidth - 10;
    }

    // Top position: align with avatar top
    // Ideally we would center it vertically, but we don't know the card height yet.
    // Top alignment is a safe default.
    double top = offset.dy;

    // Simple boundary check for left edge (in case it flipped to left and went off screen)
    if (left < 10) left = 10;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: MouseRegion(
          onEnter: (_) => _hideTimer?.cancel(),
          onExit: (_) => _hideOverlay(),
          child: Material(
            color: Colors.transparent,
            child: _UserInfoCardWrapper(
              userName: widget.userName,
              avatarUrl: widget.avatarUrl,
              initialUser: _cachedUser,
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
    _currentOverlayEntry = _overlayEntry;
    _currentHoverState = this;

    // Trigger fetch immediately if needed
    if (_cachedUser == null && !_isLoading) {
      _fetchUserInfo();
    }
  }

  void _hideOverlay() {
    if (!mounted) return;
    _showTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 200), () {
      if (_overlayEntry == _currentOverlayEntry) {
        _removeCurrentOverlay();
      } else {
        if (_overlayEntry?.mounted == true) {
          _overlayEntry?.remove();
        }
      }
      _overlayEntry = null;
    });
  }

  Future<void> _fetchUserInfo() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final api = context.read<AuthProvider>().api;
      final user = await api.getUserInfo(widget.userName);
      if (mounted) {
        _cachedUser = user;
        _isLoading = false;
        // Update overlay if it exists
        if (_overlayEntry != null) {
          _overlayEntry!.markNeedsBuild();
        }
      }
    } catch (e) {
      if (mounted) _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _scheduleShowOverlay(),
      onExit: (_) => _hideOverlay(),
      child: GestureDetector(
        onTap: () {
          context.push('/member/${widget.userName}');
        },
        child: widget.child,
      ),
    );
  }
}

// Wrapper to handle data updates in the overlay
class _UserInfoCardWrapper extends StatelessWidget {
  final String userName;
  final String avatarUrl;
  final User? initialUser;

  const _UserInfoCardWrapper({
    required this.userName,
    required this.avatarUrl,
    this.initialUser,
  });

  @override
  Widget build(BuildContext context) {
    return UserInfoCard(
      userName: userName,
      avatarUrl: avatarUrl,
      userDetails: initialUser,
      isLoading: initialUser == null,
    );
  }
}
