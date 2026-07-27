import 'dart:async';
import 'dart:math';

import 'package:ahs/app/app_theme.dart';
import 'package:ahs/data/local/database_helper.dart';
import 'package:ahs/features/navigation/app_shell.dart';
import 'package:ahs/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  runApp(const AHSApp());
}

class AHSApp extends StatelessWidget {
  const AHSApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Automated Hydrophonic System',
    debugShowCheckedModeBanner: false,
    theme: AHSTheme.light,
    home: const WelcomeScreen(),
  );
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _float;
  String _loadingText = 'Preparing local storage';
  bool _failed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: 2200.ms)
      ..repeat(reverse: true);
    _float = AnimationController(vsync: this, duration: 3000.ms)
      ..repeat(reverse: true);
    unawaited(_prepareApp());
  }

  @override
  void dispose() {
    _pulse.dispose();
    _float.dispose();
    super.dispose();
  }

  Future<void> _prepareApp() async {
    try {
      await Future<void>.delayed(450.ms);
      if (mounted) setState(() => _loadingText = 'Loading plant records');
      await DatabaseHelper.instance.getAllPlants();
      if (mounted) setState(() => _loadingText = 'Checking device battery');
      await DatabaseHelper.instance.getBatteryPercent();
      await Future<void>.delayed(650.ms);
      _navigate();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loadingText = 'Unable to prepare app data';
      });
    }
  }

  void _navigate() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: 550.ms,
        pageBuilder: (_, _, _) => const AppShell(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AHSColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              const Spacer(),
              AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, _) {
                      final glow = Curves.easeInOut.transform(_pulse.value);
                      return Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: AHSColors.primaryLight.withAlpha(
                              (80 + 90 * glow).round(),
                            ),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AHSColors.primary.withAlpha(
                                (24 + 55 * glow).round(),
                              ),
                              blurRadius: 34,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _float,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(
                                0,
                                -4 + 8 * sin(_float.value * pi),
                              ),
                              child: child,
                            ),
                            child: Image.asset(
                              'assets/ahs_finallogo.png',
                              width: 82,
                              height: 82,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.eco_rounded,
                                size: 64,
                                color: AHSColors.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(.9, .9)),
              const SizedBox(height: 34),
              const Text(
                'AUTOMATED HYDROPHONIC APP',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: AHSColors.textDark,
                  letterSpacing: 0,
                  height: 1.15,
                ),
              ).animate().fadeIn(delay: 120.ms, duration: 450.ms),
              const SizedBox(height: 10),
              const Text(
                'Plant monitoring, harvest tracking, and local analytics',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AHSColors.textSoft,
                  height: 1.35,
                ),
              ).animate().fadeIn(delay: 240.ms, duration: 450.ms),
              const SizedBox(height: 42),
              if (_failed)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _failed = false;
                      _loadingText = 'Preparing local storage';
                    });
                    unawaited(_prepareApp());
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                )
              else
                Container(
                  width: 230,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AHSColors.bgCard,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AHSColors.border, width: 1.4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: const LinearProgressIndicator(
                      minHeight: 8,
                      backgroundColor: AHSColors.divider,
                      color: AHSColors.primary,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: 220.ms,
                child: Text(
                  _loadingText,
                  key: ValueKey(_loadingText),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _failed ? AHSColors.critical : AHSColors.textMid,
                  ),
                ),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Text(
                  'Chamber 01',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AHSColors.textHint,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
