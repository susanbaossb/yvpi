import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import 'user_info_card.dart';

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

class _HoverUserCardState extends State<HoverUserCard> {
  OverlayEntry? _overlayEntry;
  Timer? _hideTimer;
  User? _cachedUser;
  bool _isLoading = false;

  // Static variable to track the currently showing overlay
  static OverlayEntry? _currentOverlayEntry;
  static _HoverUserCardState? _currentHoverState;

  @override
  void dispose() {
    _hideTimer?.cancel();
    if (_overlayEntry == _currentOverlayEntry) {
      _removeCurrentOverlay();
    }
    super.dispose();
  }

  static void _removeCurrentOverlay() {
    if (_currentOverlayEntry?.mounted == true) {
      _currentOverlayEntry?.remove();
    }
    _currentOverlayEntry = null;
    _currentHoverState?._overlayEntry =
        null; // Ensure the state knows it's removed
    _currentHoverState = null;
  }

  void _showOverlay() {
    _hideTimer?.cancel();

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

    // Card width is 320
    const cardWidth = 320.0;
    // Center horizontally relative to the avatar
    double left = offset.dx + size.width / 2 - cardWidth / 2;

    // Simple boundary check (assuming screen width is available via overlay context)
    // For now, just ensure it's not too far left
    // if (left < 10) left = 10;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: offset.dy + size.height + 10,
        child: MouseRegion(
          onEnter: (_) => _hideTimer?.cancel(),
          onExit: (_) => _hideOverlay(),
          child: Material(
            color: Colors.transparent,
            child: _UserInfoCardWrapper(
              userName: widget.userName,
              avatarUrl: widget.avatarUrl,
              initialUser: _cachedUser,
              onInit: () {
                if (_cachedUser == null && !_isLoading) {
                  _fetchUserInfo();
                }
              },
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
    _currentOverlayEntry = _overlayEntry;
    _currentHoverState = this;
  }

  void _hideOverlay() {
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
      onEnter: (_) => _showOverlay(),
      onExit: (_) => _hideOverlay(),
      child: widget.child,
    );
  }
}

// Wrapper to handle data updates in the overlay
class _UserInfoCardWrapper extends StatelessWidget {
  final String userName;
  final String avatarUrl;
  final User? initialUser;
  final VoidCallback onInit;

  const _UserInfoCardWrapper({
    required this.userName,
    required this.avatarUrl,
    this.initialUser,
    required this.onInit,
  });

  @override
  Widget build(BuildContext context) {
    // Trigger data fetch if needed
    WidgetsBinding.instance.addPostFrameCallback((_) => onInit());

    return UserInfoCard(
      userName: userName,
      avatarUrl: avatarUrl,
      userDetails: initialUser,
      isLoading: initialUser == null,
    );
  }
}
