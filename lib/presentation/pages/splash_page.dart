import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../config/app_routes.dart';
import '../../data/services/api_service.dart';
import '../../data/services/session_service.dart';
import '../../utils/helpers/snackbar_helper.dart';
import '../../utils/helpers/size_config.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  static const List<String> _images = [
    'assets/images/1.png',
    'assets/images/2.png',
    'assets/images/3.png',
    'assets/images/4.png',
  ];

  int _currentIndex = 0;
  int _nextIndex = 1;
  bool _transitioning = false;

  late AnimationController _bgController;
  late Animation<double> _bgAnim;

  late AnimationController _contentController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  Timer? _imageTimer;
  final _bottomNavKey = GlobalKey<_BottomNavState>();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    _contentController.forward();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _bgAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeInOut),
    );

    _imageTimer = Timer.periodic(const Duration(seconds: 3), (_) => _next());
    _resumeLogin();
  }

  /// Skips the splash for players who are already logged in.
  Future<void> _resumeLogin() async {
    final session = Get.find<SessionService>();
    if (!session.isLoggedIn) return;
    try {
      final route = await session.resumeSession();
      if (!mounted) return;
      if (route != null) Get.offAllNamed(route);
    } on ApiException catch (e) {
      if (mounted) AppSnackbar.warning("Couldn't load your profile", e.message);
    }
  }

  void _next() {
    if (_transitioning || !mounted) return;
    _transitioning = true;
    _nextIndex = (_currentIndex + 1) % _images.length;

    _bgController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _currentIndex = _nextIndex;
        _transitioning = false;
      });
      _bgController.reset();
    });
  }

  @override
  void dispose() {
    _imageTimer?.cancel();
    _bgController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onStart() {
    Get.toNamed(AppRoutes.login)
        ?.then((_) => _bottomNavKey.currentState?.reset());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Base image ────────────────────────────────────────
          Image.asset(_images[_currentIndex], fit: BoxFit.cover),

          // ── Next image crossfades in ──────────────────────────
          AnimatedBuilder(
            animation: _bgAnim,
            builder: (_, __) => Opacity(
              opacity: _bgAnim.value,
              child: Image.asset(_images[_nextIndex], fit: BoxFit.cover),
            ),
          ),

          // ── Gradient scrim ────────────────────────────────────
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.45, 1.0],
                colors: [
                  Color(0x66000000),
                  Color(0x33000000),
                  Color(0xCC000000),
                ],
              ),
            ),
          ),

          // ── UI content ────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App name
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    SizeConfig.w(28), SizeConfig.h(20),
                    SizeConfig.w(28), 0,
                  ),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Image.asset(
                      'assets/images/paltan_logo_text.png',
                      height: SizeConfig.h(28),
                    ),
                  ),
                ),

                SizedBox(height: SizeConfig.h(32)),

                // Headline
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(28)),
                  child: SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Text(
                        'Join,\nPlay,\nRepeat.',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Gilroy',
                          fontWeight: FontWeight.w900,
                          fontSize: SizeConfig.sp(76),
                          height: 1.05,
                          letterSpacing: SizeConfig.w(-0.5),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Dot indicators
                FadeTransition(
                  opacity: _fadeAnim,
                  child: _ImageDots(
                    count: _images.length,
                    currentIndex: _currentIndex,
                  ),
                ),

                SizedBox(height: SizeConfig.h(20)),

                // Slide-to-play
                FadeTransition(
                  opacity: _fadeAnim,
                  child: _BottomNav(key: _bottomNavKey, onStart: _onStart),
                ),
                SizedBox(height: SizeConfig.h(28)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dot indicators ──────────────────────────────────────────────────────────

class _ImageDots extends StatelessWidget {
  final int count;
  final int currentIndex;

  const _ImageDots({required this.count, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(28)),
      child: Row(
        children: List.generate(count, (i) {
          final active = i == currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            margin: EdgeInsets.only(right: SizeConfig.w(6)),
            width: active ? SizeConfig.w(24) : SizeConfig.w(6),
            height: SizeConfig.h(6),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white.withAlpha(80),
              borderRadius: BorderRadius.circular(SizeConfig.r(3)),
            ),
          );
        }),
      ),
    );
  }
}

// ─── iOS-style slide-to-start ─────────────────────────────────────────────────

class _BottomNav extends StatefulWidget {
  final VoidCallback onStart;
  const _BottomNav({super.key, required this.onStart});

  @override
  State<_BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<_BottomNav> with TickerProviderStateMixin {
  double get _thumbSize => SizeConfig.r(54);
  double get _trackPadding => SizeConfig.r(7);
  double get _trackHeight => SizeConfig.r(68);

  double _dragPos = 0.0;
  double _trackWidth = 0.0;
  bool _completed = false;

  late AnimationController _snapController;
  late Animation<double> _snapAnim;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  double get _maxDrag => _trackWidth - _thumbSize - _trackPadding * 2;
  double get _progress => _maxDrag > 0 ? (_dragPos / _maxDrag).clamp(0.0, 1.0) : 0.0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void reset() {
    if (!mounted) return;
    setState(() {
      _dragPos = 0;
      _completed = false;
    });
    _pulseController.repeat(reverse: true);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_completed) return;
    if (_snapController.isAnimating) _snapController.stop();
    setState(() => _dragPos = (_dragPos + d.delta.dx).clamp(0.0, _maxDrag));
  }

  void _onDragEnd(DragEndDetails _) {
    if (_completed) return;
    if (_progress >= 0.82) {
      _pulseController.stop();
      setState(() {
        _completed = true;
        _dragPos = _maxDrag;
      });
      Future.delayed(const Duration(milliseconds: 350), widget.onStart);
    } else {
      final from = _dragPos;
      _snapAnim = Tween<double>(begin: from, end: 0).animate(
        CurvedAnimation(parent: _snapController, curve: Curves.elasticOut),
      )..addListener(() => setState(() => _dragPos = _snapAnim.value));
      _snapController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(28)),
      child: LayoutBuilder(builder: (_, constraints) {
        _trackWidth = constraints.maxWidth;

        return Container(
          height: _trackHeight,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(_trackHeight),
            border: Border.all(color: Colors.white.withAlpha(60), width: 1),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.hardEdge,
            children: [
              // Fill
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_trackHeight),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (_trackPadding / _trackWidth) +
                          _progress * ((_thumbSize + _trackPadding) / _trackWidth),
                      child: Container(color: Colors.white.withAlpha(30)),
                    ),
                  ),
                ),
              ),

              // Label
              Center(
                child: Opacity(
                  opacity: (1.0 - _progress * 2).clamp(0.0, 1.0),
                  child: Text(
                    'Slide to Play',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w600,
                      fontSize: SizeConfig.sp(15),
                      letterSpacing: SizeConfig.w(0.2),
                    ),
                  ),
                ),
              ),

              // Pulsing chevrons
              Positioned(
                right: SizeConfig.w(18),
                child: Opacity(
                  opacity: (1.0 - _progress * 2).clamp(0.0, 1.0),
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Row(
                      children: List.generate(
                        3,
                        (i) => Opacity(
                          opacity: (_pulseAnim.value - i * 0.25).clamp(0.0, 1.0),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: SizeConfig.r(18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Thumb
              Positioned(
                left: _trackPadding + _dragPos,
                child: GestureDetector(
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: _completed ? const Color(0xFF4CAF50) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(60),
                          blurRadius: SizeConfig.r(10),
                          offset: Offset(SizeConfig.w(2), SizeConfig.h(3)),
                        ),
                      ],
                    ),
                    child: Icon(
                      _completed ? Icons.check_rounded : Icons.play_arrow_rounded,
                      color: _completed ? Colors.white : AppColors.primary,
                      size: SizeConfig.r(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
