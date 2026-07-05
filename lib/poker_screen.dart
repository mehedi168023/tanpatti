import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'widgets/poker_card.dart';

class PokerScreen extends StatefulWidget {
  const PokerScreen({super.key});

  @override
  State<PokerScreen> createState() => _PokerScreenState();
}

class _PokerScreenState extends State<PokerScreen> with TickerProviderStateMixin {
  // Game state tracker:
  // 1: Own Turn, pre-flop (Screenshot 1)
  // 2: Shohag's Turn, banner Mehidi calls (Screenshot 2)
  // 3: Own Turn, flop dealt, check/raise options, raise slider open (Screenshot 3)
  // 4: Own Turn, flop dealt, call/raise options, Rahiyan raised (Screenshot 4)
  // 5: Showdown / Win state! (Extra reward experience)
  int _stateIndex = 1;

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Raise values
  double _raiseValue = 10500;
  final double _minRaise = 1500;
  final double _maxRaise = 58500;
  bool _showRaiseSlider = false;

  // Timers and animations
  double _timerProgress = 0.75; // Depleting yellow bar for own turn
  double _opponentTimerProgress = 1.0; // Depleting circle for Shohag
  Timer? _turnTimer;
  Timer? _state2DelayTimer;

  // Pulse animation for active glowing aura
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Initialize glowing animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 3.0, end: 12.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _startTimer();
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    _state2DelayTimer?.cancel();
    _glowController.dispose();
    _audioPlayer.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _playSound() {
    _audioPlayer.play(AssetSource('sounds/chips_collect.mp3')).catchError((e) {
      debugPrint("Audio play error: $e");
    });
  }

  void _startTimer() {
    _turnTimer?.cancel();
    _timerProgress = 0.75;
    _turnTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) return;
      setState(() {
        if (_stateIndex == 1 || _stateIndex == 3 || _stateIndex == 4) {
          _timerProgress -= 0.015;
          if (_timerProgress <= 0) {
            _timerProgress = 1.0; // Auto reset or time out
          }
        }
      });
    });
  }

  void _transitionToState2() {
    _playSound();
    setState(() {
      _stateIndex = 2;
      _showRaiseSlider = false;
      _opponentTimerProgress = 1.0;
    });

    // Animate Shohag's circular progress timer
    _state2DelayTimer?.cancel();
    const duration = Duration(milliseconds: 100);
    int elapsed = 0;
    _state2DelayTimer = Timer.periodic(duration, (timer) {
      if (!mounted) return;
      setState(() {
        elapsed += 100;
        _opponentTimerProgress = 1.0 - (elapsed / 3000); // 3 seconds total
        if (elapsed >= 3000) {
          timer.cancel();
          _transitionToState3();
        }
      });
    });
  }

  void _transitionToState3() {
    _playSound();
    setState(() {
      _stateIndex = 3;
      _showRaiseSlider = true; // Slider starts open in Screenshot 3
      _raiseValue = 10500;
    });
    _startTimer();
  }

  void _transitionToState4() {
    _playSound();
    setState(() {
      _stateIndex = 4;
      _showRaiseSlider = false;
    });
    _startTimer();
  }

  void _transitionToShowdown() {
    _playSound();
    setState(() {
      _stateIndex = 5;
      _showRaiseSlider = false;
    });
    _turnTimer?.cancel();

    // Reset loop back to State 1 after 4.5 seconds
    Future.delayed(const Duration(milliseconds: 4500), () {
      if (mounted) {
        setState(() {
          _stateIndex = 1;
        });
        _startTimer();
      }
    });
  }

  // Action Button Builder
  Widget _buildActionButton({
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onPressed,
    String? subtitle,
    Widget? icon,
    double widthFactor = 1.0,
  }) {
    return Expanded(
      flex: (widthFactor * 100).round(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) icon,
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2),
                      ],
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.yellowAccent.withOpacity(0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Glowing Avatar Frame (pulsing when active)
  Widget _buildAvatar({
    required String imageAsset,
    required bool isActive,
    required double size,
    Color activeColor = const Color(0xFFFFEB3B),
    double timerVal = 1.0,
    bool isCircularTimer = false,
  }) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Circular progress timer track around avatar (for opponents)
            if (isActive && isCircularTimer)
              SizedBox(
                width: size + 8,
                height: size + 8,
                child: CircularProgressIndicator(
                  value: timerVal,
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                  backgroundColor: Colors.black26,
                ),
              ),
            // Glowing border
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: isActive && !isCircularTimer
                    ? [
                        BoxShadow(
                          color: activeColor.withOpacity(0.8),
                          blurRadius: _glowAnimation.value,
                          spreadRadius: _glowAnimation.value * 0.4,
                        ),
                      ]
                    : [
                        const BoxShadow(
                          color: Colors.black54,
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? activeColor : const Color(0xFFD4AF37),
                    width: 2.2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(imageAsset, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Seat Component (Opponents and Empty seat)
  Widget _buildSeat({
    required String name,
    required String chips,
    required String avatarAsset,
    required String actionText,
    required String betAmount,
    required double x, // -1.0 to 1.0 relative X
    required double y, // -1.0 to 1.0 relative Y
    required bool isActive,
    required List<Widget> cardWidgets,
    bool isInvite = false,
    bool isCircularTimer = false,
    double circularTimerVal = 1.0,
    bool showDealerBtn = false,
    bool showStars = false,
    bool showCrown = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // Position coordinates mapped to landscape screen center
        final left = (w / 2) * (1 + x) - 40;
        final top = (h / 2) * (1 + y) - 40;

        if (isInvite) {
          return Positioned(
            left: left,
            top: top - 15,
            child: Column(
              children: [
                const Text(
                  'Invite',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black38,
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.person, color: Colors.white30, size: 28),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -10),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          );
        }

        final isFolded = actionText == 'Fold';

        return Positioned(
          left: left - 25,
          top: top - 35,
          width: 130,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Player name
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
              // Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/poker_chip.png', width: 11, height: 11),
                  const SizedBox(width: 3),
                  Text(
                    chips,
                    style: const TextStyle(
                      color: Color(0xFFBDBDBD),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Avatar with active state and optional crowns/stars/dealer button
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: isFolded ? 0.5 : 1.0,
                    child: _buildAvatar(
                      imageAsset: avatarAsset,
                      isActive: isActive,
                      size: 58,
                      timerVal: circularTimerVal,
                      isCircularTimer: isCircularTimer,
                      activeColor: Colors.yellowAccent,
                    ),
                  ),
                  // Gift Button Overlay
                  Positioned(
                    left: -12,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 2)],
                      ),
                      child: const Icon(Icons.card_giftcard, color: Colors.grey, size: 12),
                    ),
                  ),
                  // D dealer button
                  if (showDealerBtn)
                    Positioned(
                      left: -14,
                      top: 12,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black87, width: 1),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'D',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  // Silver Stars
                  if (showStars)
                    Positioned(
                      right: -10,
                      top: -12,
                      child: Row(
                        children: const [
                          Icon(Icons.star, color: Colors.white70, size: 9),
                          Icon(Icons.star, color: Colors.white70, size: 11),
                          Icon(Icons.star, color: Colors.white70, size: 9),
                        ],
                      ),
                    ),
                  // Gold Crown
                  if (showCrown)
                    Positioned(
                      right: -10,
                      top: -10,
                      child: Transform.rotate(
                        angle: 0.25,
                        child: const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 16),
                      ),
                    ),
                  // Action Text Bubble (Fold/Call/Raise)
                  if (actionText.isNotEmpty)
                    Positioned(
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFolded ? const Color(0xFFC62828) : Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isFolded ? Colors.white70 : Colors.white24,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          actionText.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // Folded Text Overlay in center of avatar
              if (isFolded)
                const Positioned(
                  top: 38,
                  child: IgnorePointer(
                    child: Text(
                      'FOLD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ),
                ),
              // Bet Chips amount
              if (betAmount.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/poker_chip.png', width: 13, height: 13),
                      const SizedBox(width: 4),
                      Text(
                        betAmount,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Player Hand Cards
              if (cardWidgets.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: cardWidgets,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Raise Vertical Slider
  Widget _buildRaiseSlider() {
    return Positioned(
      right: 14,
      bottom: 60,
      width: 120,
      height: 240,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: Column(
          children: [
            // All In button
            GestureDetector(
              onTap: () {
                setState(() {
                  _raiseValue = _maxRaise;
                });
                _playSound();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.cyanAccent, width: 1),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'ALL IN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Slider Row with vertical track
            Expanded(
              child: Row(
                children: [
                  // Presets Column
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPresetBubble('₹45,000', 45000),
                        _buildPresetBubble('₹30,000', 30000),
                        _buildPresetBubble('₹16,500', 16500),
                        _buildPresetBubble('₹10,500', 10500),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Slider + & - buttons + Track
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Plus button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _raiseValue = math.min(_maxRaise, _raiseValue + 1500);
                          });
                          _playSound();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 16),
                        ),
                      ),
                      // Vertical track indicator with chips handle
                      Expanded(
                        child: GestureDetector(
                          onVerticalDragUpdate: (details) {
                            // Map drag coordinates to value
                            double percent = (1.0 - (details.localPosition.dy / 100)).clamp(0.0, 1.0);
                            setState(() {
                              _raiseValue = _minRaise + (_maxRaise - _minRaise) * percent;
                              // Round to nearest 500
                              _raiseValue = (_raiseValue / 500).round() * 500;
                            });
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Track Line
                              Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // Chip stack handle (moves vertically)
                              Positioned(
                                bottom: (() {
                                  double pct = (_raiseValue - _minRaise) / (_maxRaise - _minRaise);
                                  return pct * 90; // scale limit of track
                                })(),
                                child: Image.asset(
                                  'assets/images/chip_stack.png',
                                  width: 28,
                                  height: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Minus button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _raiseValue = math.max(_minRaise, _raiseValue - 1500);
                          });
                          _playSound();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.remove, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Selected Bubble Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '₹${_raiseValue.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Close Button
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 16),
              onPressed: () {
                setState(() {
                  _showRaiseSlider = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetBubble(String label, double val) {
    bool isSelected = (_raiseValue - val).abs() < 500;
    return GestureDetector(
      onTap: () {
        setState(() {
          _raiseValue = val;
        });
        _playSound();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyanAccent : Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Developer State Selector Overlay (Collapsible for easy debugging)
  bool _showDebugMenu = false;
  Widget _buildDebugMenu() {
    return Positioned(
      top: 50,
      left: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.cyanAccent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(60, 24),
            ),
            onPressed: () => setState(() => _showDebugMenu = !_showDebugMenu),
            child: const Text('STATES', style: TextStyle(fontSize: 10)),
          ),
          if (_showDebugMenu)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Color(0xDE000000),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.cyanAccent),
              ),
              child: Column(
                children: [
                  for (int i = 1; i <= 5; i++)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: const Size(50, 20),
                        foregroundColor: _stateIndex == i ? Colors.yellow : Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _stateIndex = i;
                          _showRaiseSlider = (i == 3);
                          if (i == 2) {
                            _opponentTimerProgress = 1.0;
                          }
                        });
                        _startTimer();
                      },
                      child: Text('Screen $i', style: const TextStyle(fontSize: 10)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Current state values
    String ownChips = '₹59,250';
    String potAmount = '₹5,250';
    String bannerText = '';

    if (_stateIndex == 1) {
      ownChips = '₹59,250';
      potAmount = '₹5,250';
    } else if (_stateIndex == 2) {
      ownChips = '₹58,500';
      potAmount = '₹6,000';
      bannerText = 'Mehidi calls ₹750';
    } else if (_stateIndex == 3) {
      ownChips = '₹58,500';
      potAmount = '₹6,000';
    } else if (_stateIndex == 4) {
      ownChips = '₹58,500';
      potAmount = '₹7,500';
    } else if (_stateIndex == 5) {
      ownChips = '₹66,000';
      potAmount = '₹7,500';
      bannerText = 'Showdown! Mehidi Wins!';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF072013),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-bleed background felt image
          const Image(
            image: AssetImage('assets/images/poker_bg_full.png'),
            fit: BoxFit.cover,
          ),

          // 2. Table layer
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Table Image
                  Positioned(
                    left: 40,
                    right: 40,
                    top: 25,
                    bottom: 25,
                    child: Image.asset(
                      'assets/images/poker_table.png',
                      fit: BoxFit.fill,
                    ),
                  ),

                  // Center Logo / Text on Felt
                  Positioned(
                    top: 135,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'TEEN PATTI GOLD',
                        style: TextStyle(
                          color: const Color(0xFFFFD700).withOpacity(0.08),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),

                  // 3. Dealer Woman
                  Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      heightFactor: 0.42,
                      child: Image.asset(
                        'assets/images/poker_dealer.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Dealer Tip Button
                  Positioned(
                    top: 86,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                        ),
                        child: const Text(
                          'Tip',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Pot Chips representation
                  Positioned(
                    top: 108,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset('assets/images/chip_stack.png', width: 22, height: 16),
                            const SizedBox(width: 4),
                            Text(
                              potAmount,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. Five Card Placeholders on Table Center
                  Positioned(
                    top: 146,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Card 1
                        _stateIndex >= 3
                            ? const PokerCard(rank: '6', suit: CardSuit.clubs, width: 44, height: 60)
                            : _buildEmptyCardPlaceholder(),
                        const SizedBox(width: 4),
                        // Card 2
                        _stateIndex >= 3
                            ? const PokerCard(rank: '4', suit: CardSuit.clubs, width: 44, height: 60)
                            : _buildEmptyCardPlaceholder(),
                        const SizedBox(width: 4),
                        // Card 3
                        _stateIndex >= 3
                            ? const PokerCard(rank: 'Q', suit: CardSuit.diamonds, width: 44, height: 60)
                            : _buildEmptyCardPlaceholder(),
                        const SizedBox(width: 4),
                        // Card 4 (Turn)
                        _stateIndex >= 5
                            ? const PokerCard(rank: 'J', suit: CardSuit.hearts, width: 44, height: 60)
                            : _buildEmptyCardPlaceholder(dotted: true),
                        const SizedBox(width: 4),
                        // Card 5 (River)
                        _stateIndex >= 5
                            ? const PokerCard(rank: '10', suit: CardSuit.clubs, width: 44, height: 60)
                            : _buildEmptyCardPlaceholder(dotted: true),
                      ],
                    ),
                  ),

                  // 5. Opponent Seats
                  // Seat 1: PRO (Top Left)
                  _buildSeat(
                    name: 'PRO',
                    chips: '₹39,000',
                    avatarAsset: 'assets/images/avatar_left1.png',
                    actionText: _stateIndex == 4 ? 'Check' : (_stateIndex == 5 ? 'Check' : 'Call'),
                    betAmount: _stateIndex == 3 ? '' : '₹1,500',
                    x: -0.48,
                    y: -0.45,
                    isActive: false,
                    showStars: true,
                    cardWidgets: [
                      const PokerCard(rank: 'A', suit: CardSuit.spades, isFaceUp: false, width: 14, height: 20),
                      const PokerCard(rank: 'A', suit: CardSuit.spades, isFaceUp: false, width: 14, height: 20),
                    ],
                  ),

                  // Seat 2: Shohag (Bottom Left / Left)
                  _buildSeat(
                    name: 'Shohag',
                    chips: '₹1.23 L',
                    avatarAsset: 'assets/images/avatar_left2.png',
                    actionText: _stateIndex == 1
                        ? 'Big Blind'
                        : (_stateIndex == 2
                            ? 'Big Blind'
                            : (_stateIndex == 3
                                ? 'Check'
                                : (_stateIndex == 4 ? 'Check' : 'Fold'))),
                    betAmount: _stateIndex == 3 ? '' : '₹1,500',
                    x: -0.63,
                    y: 0.16,
                    isActive: _stateIndex == 2,
                    isCircularTimer: true,
                    circularTimerVal: _opponentTimerProgress,
                    cardWidgets: [
                      const PokerCard(rank: 'A', suit: CardSuit.spades, isFaceUp: false, width: 14, height: 20),
                      const PokerCard(rank: 'A', suit: CardSuit.spades, isFaceUp: false, width: 14, height: 20),
                    ],
                  ),

                  // Seat 3: Rahiyan (Top Right)
                  _buildSeat(
                    name: 'Rahiyan',
                    chips: (_stateIndex >= 4) ? '₹57,000' : '₹58,500',
                    avatarAsset: 'assets/images/avatar_right1.png',
                    actionText: _stateIndex >= 4 ? 'Raise' : 'Call',
                    betAmount: _stateIndex == 3 ? '' : '₹1,500',
                    x: 0.48,
                    y: -0.45,
                    isActive: false,
                    showDealerBtn: true,
                    showCrown: true,
                    cardWidgets: [
                      const PokerCard(rank: 'A', suit: CardSuit.spades, isFaceUp: false, width: 14, height: 20),
                      const PokerCard(rank: 'A', suit: CardSuit.spades, isFaceUp: false, width: 14, height: 20),
                    ],
                  ),

                  // Seat 4: Empty Seat / Invite (Bottom Right)
                  _buildSeat(
                    name: '',
                    chips: '',
                    avatarAsset: '',
                    actionText: '',
                    betAmount: '',
                    x: 0.63,
                    y: 0.16,
                    isActive: false,
                    isInvite: true,
                    cardWidgets: [],
                  ),

                  // 6. Own Player Avatar and Details (Bottom Center)
                  Positioned(
                    bottom: 36,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Own Cards (2 of Spades & King of Diamonds)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 2 of Spades rotated CCW
                              PokerCard(
                                rank: '2',
                                suit: CardSuit.spades,
                                width: 48,
                                height: 66,
                                rotation: -0.15,
                              ),
                              const SizedBox(width: 4),
                              // K of Diamonds rotated CW, overlapping
                              PokerCard(
                                rank: 'K',
                                suit: CardSuit.diamonds,
                                width: 48,
                                height: 66,
                                rotation: 0.15,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Own turn progress bar (horizontal orange bar)
                          if (_stateIndex == 1 || _stateIndex == 3 || _stateIndex == 4)
                            Container(
                              width: 80,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _timerProgress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                                    ),
                                    borderRadius: BorderRadius.circular(2.5),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),

                          // Profile Avatar Frame
                          Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              _buildAvatar(
                                imageAsset: 'assets/images/avatar_own.png',
                                isActive: _stateIndex == 1 || _stateIndex == 3 || _stateIndex == 4,
                                size: 54,
                                activeColor: Colors.yellowAccent,
                              ),
                              // Gift icon
                              Positioned(
                                right: -12,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 2)],
                                  ),
                                  child: const Icon(Icons.card_giftcard, color: Colors.grey, size: 11),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 7. System notification banners under the dealer
                  if (bannerText.isNotEmpty)
                    Positioned(
                      top: 60,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            bannerText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 8. Top Control Bar (HUD)
          Positioned(
            top: 8,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back & Buy Section
                Row(
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Buy Button
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Image.asset('assets/images/poker_chip.png', width: 16, height: 16),
                          const SizedBox(width: 4),
                          const Text(
                            'Buy',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Info, Chat and Friend Settings
                Row(
                  children: [
                    // Info icon
                    _buildHUDButton(Icons.info_outline, () {}),
                    const SizedBox(width: 8),
                    // Chat icon
                    _buildHUDButton(Icons.chat_bubble_outline_rounded, () {}),
                    const SizedBox(width: 8),
                    // Friends icon
                    _buildHUDButton(Icons.group_outlined, () {}),
                  ],
                ),
              ],
            ),
          ),

          // 9. Side "?" Help Button
          Positioned(
            left: 10,
            bottom: 120,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '?',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // 10. Bottom Action Bar (Controllable based on State & Turn)
          if (_stateIndex == 1 || _stateIndex == 3 || _stateIndex == 4)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xDC09100D), // Sleek glossy background
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    // Fold button (always visible)
                    _buildActionButton(
                      label: 'Fold',
                      gradientColors: [const Color(0xFFC62828), const Color(0xFF8E0000)],
                      onPressed: () {
                        // Reset round on Fold
                        setState(() {
                          _stateIndex = 1;
                        });
                        _startTimer();
                      },
                      widthFactor: 0.9,
                    ),

                    // Chip Box (Displays total remaining chips)
                    Expanded(
                      flex: 140,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF13221B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset('assets/images/chip_stack.png', width: 22, height: 22),
                                const SizedBox(width: 6),
                                Text(
                                  ownChips,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            // "15 days" promotional banner/badge
                            Positioned(
                              top: 2,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '15 days',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 7,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Middle action button (Call / Check / Call Raised)
                    if (_stateIndex == 1)
                      _buildActionButton(
                        label: 'Call',
                        subtitle: '₹750',
                        gradientColors: [const Color(0xFFD32F2F), const Color(0xFF9E0D0D)],
                        onPressed: _transitionToState2,
                        widthFactor: 0.9,
                      ),
                    if (_stateIndex == 3)
                      _buildActionButton(
                        label: 'Check',
                        gradientColors: [const Color(0xFFE53935), const Color(0xFFB71C1C)],
                        onPressed: _transitionToState4,
                        widthFactor: 0.9,
                      ),
                    if (_stateIndex == 4)
                      _buildActionButton(
                        label: 'Call',
                        subtitle: '₹1,500',
                        gradientColors: [const Color(0xFFD32F2F), const Color(0xFF9E0D0D)],
                        onPressed: _transitionToShowdown,
                        widthFactor: 0.9,
                      ),

                    // Raise Button
                    _buildActionButton(
                      label: 'Raise',
                      subtitle: _stateIndex == 3 ? '₹${_raiseValue.toStringAsFixed(0)}' : null,
                      icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 14),
                      gradientColors: [const Color(0xFF5E35B1), const Color(0xFF311B92)],
                      onPressed: () {
                        if (_stateIndex == 3) {
                          // In state 3, clicking raise submits the raise
                          _transitionToState4();
                        } else {
                          // Toggle raise slider overlay
                          setState(() {
                            _showRaiseSlider = !_showRaiseSlider;
                          });
                        }
                      },
                      widthFactor: 0.9,
                    ),
                  ],
                ),
              ),
            ),

          // Showown / Win overlay for State 5
          if (_stateIndex == 5)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Reward Banner card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE6C619), Color(0xFFC78018)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 15, spreadRadius: 2),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.workspace_premium, color: Colors.white, size: 48),
                            const SizedBox(height: 8),
                            const Text(
                              'SHOWDOWN!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'MEHIDI WINS THE ROUND',
                              style: TextStyle(
                                color: Color(0xFFB5B5B5),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset('assets/images/chip_stack.png', width: 28, height: 28),
                                const SizedBox(width: 8),
                                const Text(
                                  '+₹7,500',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Starting next hand in a few seconds...',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 11. Raise Vertical Slider Overlay
          if (_showRaiseSlider && (_stateIndex == 1 || _stateIndex == 3 || _stateIndex == 4))
            _buildRaiseSlider(),

          // Developer debug state menu overlay
          _buildDebugMenu(),
        ],
      ),
    );
  }

  Widget _buildHUDButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  // Helper widget to draw card slot placeholders on the table
  Widget _buildEmptyCardPlaceholder({bool dotted = false}) {
    return Container(
      width: 44,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.white.withOpacity(dotted ? 0.15 : 0.35),
          width: dotted ? 1.0 : 1.2,
          style: dotted ? BorderStyle.solid : BorderStyle.solid, // Wait, Flutter doesn't have built-in dotted border.
        ),
      ),
      child: Center(
        child: Icon(
          Icons.crop_original,
          color: Colors.white.withOpacity(dotted ? 0.05 : 0.15),
          size: 18,
        ),
      ),
    );
  }
}
