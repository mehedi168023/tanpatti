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

  // Animation states for flying chips
  bool _isTipAnimating = false;
  bool _isBetAnimating = false;
  int _lastTickedSecond = 0;

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
    _glowAnimation = Tween<double>(begin: 8.0, end: 24.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Start shuffle sound and welcome turn notification
    Future.delayed(const Duration(milliseconds: 300), () {
      _playGameSound('card_shuffle.mp3');
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      _playGameSound('your_turn.mp3');
    });

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

  // Concurrent sound player to prevent clipping/cutting off sounds
  void _playGameSound(String filename) {
    final player = AudioPlayer();
    player.play(AssetSource('sounds/$filename')).then((_) {
      Future.delayed(const Duration(seconds: 4), () {
        player.dispose();
      });
    }).catchError((e) {
      debugPrint("Audio play error: $e");
    });
  }

  void _animateBet() {
    setState(() {
      _isBetAnimating = true;
    });
    _playGameSound('chips_jiggle.mp3');
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _isBetAnimating = false;
        });
      }
    });
  }

  void _tipDealer() {
    setState(() {
      _isTipAnimating = true;
    });
    _playGameSound('tip_dealer.mp3');
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isTipAnimating = false;
        });
      }
    });
  }

  void _startTimer() {
    _turnTimer?.cancel();
    _timerProgress = 0.75;
    _lastTickedSecond = 0;
    _turnTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) return;
      setState(() {
        if (_stateIndex == 1 || _stateIndex == 3 || _stateIndex == 4) {
          _timerProgress -= 0.015;
          
          // Ticking sound effect for critical time limit (less than 35% time left)
          if (_timerProgress < 0.35) {
            int secondsLeft = (_timerProgress * 15).ceil();
            if (secondsLeft != _lastTickedSecond) {
              _lastTickedSecond = secondsLeft;
              _playGameSound('timerNew.mp3');
            }
          }

          if (_timerProgress <= 0) {
            _timerProgress = 1.0; // Auto reset or time out
          }
        }
      });
    });
  }

  void _transitionToState2() {
    _animateBet();
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
    _playGameSound('card_deal.mp3');
    Future.delayed(const Duration(milliseconds: 800), () {
      _playGameSound('your_turn.mp3');
    });

    setState(() {
      _stateIndex = 3;
      _showRaiseSlider = true; // Slider starts open in Screenshot 3
      _raiseValue = 10500;
    });
    _startTimer();
  }

  void _transitionToState4() {
    _animateBet();
    Future.delayed(const Duration(milliseconds: 1000), () {
      _playGameSound('chaal.mp3'); // Rahiyan raised
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      _playGameSound('your_turn.mp3');
    });

    setState(() {
      _stateIndex = 4;
      _showRaiseSlider = false;
    });
    _startTimer();
  }

  void _transitionToShowdown() {
    _playGameSound('card_deal.mp3');
    Future.delayed(const Duration(milliseconds: 1000), () {
      _playGameSound('winner.mp3');
      _playGameSound('chips_collect.mp3'); // Win reward experience
    });

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
        _playGameSound('card_shuffle.mp3');
        Future.delayed(const Duration(milliseconds: 1000), () {
          _playGameSound('your_turn.mp3');
        });
        _startTimer();
      }
    });
  }

  // Action Button Builder (Floating, Glossy CASINO design)
  Widget _buildActionButton({
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onPressed,
    String? subtitle,
    Widget? icon,
  }) {
    return Container(
      width: 90,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFFFD700), // Yellow Gold border
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
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
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon,
                const SizedBox(height: 1),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 2),
                  ],
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFFFEB3B), // Bright Yellow
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Glowing Avatar Frame (pulsing when active, support circular timer)
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
            // Circular progress timer track around avatar
            if (isActive && isCircularTimer)
              SizedBox(
                width: size + 8,
                height: size + 8,
                child: CircularProgressIndicator(
                  value: timerVal,
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                  backgroundColor: Colors.white12,
                ),
              ),
            // Glowing border / aura
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: activeColor.withOpacity(0.6),
                          blurRadius: _glowAnimation.value * 1.5,
                          spreadRadius: _glowAnimation.value * 0.3,
                        ),
                      ]
                    : [
                        const BoxShadow(
                          color: Colors.black45,
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive ? activeColor : const Color(0xFFD4AF37),
                    width: 2.0,
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

  // Opponent Hand Cards Widget (Tilted and overlapping)
  Widget _buildOpponentCards() {
    return SizedBox(
      width: 36,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            child: PokerCard(
              rank: 'A',
              suit: CardSuit.spades,
              isFaceUp: false,
              width: 20,
              height: 28,
              rotation: -0.15,
            ),
          ),
          Positioned(
            right: 0,
            child: PokerCard(
              rank: 'A',
              suit: CardSuit.spades,
              isFaceUp: false,
              width: 20,
              height: 28,
              rotation: 0.15,
            ),
          ),
        ],
      ),
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
    required double tableW,
    required double tableH,
    bool isInvite = false,
    bool isCircularTimer = false,
    double circularTimerVal = 1.0,
    bool showDealerBtn = false,
    bool showStars = false,
    bool showCrown = false,
  }) {
    // Position coordinates mapped to landscape screen center
    final left = (tableW / 2) * (1 + x);
    final top = (tableH / 2) * (1 + y);

    if (isInvite) {
      return Positioned(
        left: left - 29,
        top: top - 45,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
    final isLeftPlayer = x < 0;

    return Positioned(
      left: left - 80,
      top: top - 65,
      width: 160,
      height: 130,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // 1. Name & Chips Column (at the top)
          Positioned(
            top: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  chips,
                  style: const TextStyle(
                    color: Colors.yellowAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 2. Avatar with border glow timer
          Positioned(
            top: 30,
            child: _buildAvatar(
              imageAsset: avatarAsset,
              isActive: isActive,
              size: 46,
              isCircularTimer: isCircularTimer,
              timerVal: circularTimerVal,
            ),
          ),

          // 3. Tilted overlapping opponent hand cards (rendered next to avatar)
          if (!isFolded)
            Positioned(
              top: 34,
              left: isLeftPlayer ? 104 : 12,
              child: _buildOpponentCards(),
            ),

          // 4. Gold Crown on Top Left of Avatar
          if (showCrown)
            Positioned(
              top: 14,
              left: 45,
              child: Transform.rotate(
                angle: -0.15,
                child: const Icon(
                  Icons.workspace_premium,
                  color: Color(0xFFFFD700),
                  size: 16,
                ),
              ),
            ),

          // 5. Silver Stars on Bottom Right of Avatar
          if (showStars)
            Positioned(
              top: 56,
              left: 98,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 0.8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star, color: Colors.cyanAccent, size: 7),
                    SizedBox(width: 1),
                    Icon(Icons.star, color: Colors.cyanAccent, size: 7),
                  ],
                ),
              ),
            ),

          // 6. Dealer button capsule on left/right of avatar
          if (showDealerBtn)
            Positioned(
              top: 42,
              left: isLeftPlayer ? 38 : 106,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 2)],
                ),
                child: const Center(
                  child: Text(
                    'D',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),

          // 7. Bet Chips count relative to the felt table
          if (betAmount.isNotEmpty)
            Positioned(
              top: 86,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isFolded ? const Color(0xFFC62828) : Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFolded ? Colors.redAccent : const Color(0xFF4CAF50),
                      width: 1,
                    ),
                  ),
                  child: Row(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isFolded) ...[
                      Image.asset('assets/images/poker_chip.png', width: 11, height: 11),
                      const SizedBox(width: 3),
                    ],
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
            ),
        ],
      ),
    );
  }

  // Raise Vertical Slider (Floating, matches Screenshot 3)
  Widget _buildRaiseSlider() {
    double trackHeight = 180.0;
    double trackTop = 40.0;
    double sliderWidth = 160.0;

    // Calculate Y position of handle
    double pct = (_raiseValue - _minRaise) / (_maxRaise - _minRaise);
    double handleY = trackTop + trackHeight - (pct * trackHeight);

    return Positioned(
      right: 55, // Aligned above the Raise action button
      bottom: 62,
      width: sliderWidth,
      height: 290,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Vertical Track Line
          Positioned(
            left: 80,
            top: trackTop,
            bottom: 290 - (trackTop + trackHeight),
            child: Container(
              width: 3.2,
              color: Colors.white38,
            ),
          ),

          // 2. White Tick Marks along the line
          for (double presetVal in [45000, 30000, 16500, 10500])
            Positioned(
              left: 77.5,
              top: trackTop + trackHeight - (((presetVal - _minRaise) / (_maxRaise - _minRaise)) * trackHeight) - 4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),

          // 3. Preset bubbles on the left (pointing right)
          Positioned(
            left: 5,
            top: trackTop + trackHeight - (((45000 - _minRaise) / (_maxRaise - _minRaise)) * trackHeight) - 12,
            child: _buildPresetBubble('₹45,000', 45000),
          ),
          Positioned(
            left: 5,
            top: trackTop + trackHeight - (((30000 - _minRaise) / (_maxRaise - _minRaise)) * trackHeight) - 12,
            child: _buildPresetBubble('₹30,000', 30000),
          ),
          Positioned(
            left: 5,
            top: trackTop + trackHeight - (((16500 - _minRaise) / (_maxRaise - _minRaise)) * trackHeight) - 12,
            child: _buildPresetBubble('₹16,500', 16500),
          ),
          Positioned(
            left: 5,
            top: trackTop + trackHeight - (((10500 - _minRaise) / (_maxRaise - _minRaise)) * trackHeight) - 12,
            child: _buildPresetBubble('₹10,500', 10500),
          ),

          // 4. Selection Speech Bubble (points to current handle position)
          Positioned(
            right: 86, // Positioned to the left of the handle/line
            top: handleY - 14,
            child: _buildSelectionBubble('₹${_raiseValue.toStringAsFixed(0)}'),
          ),

          // 5. Draggable Handle (Chip Stack)
          Positioned(
            left: 65, // Centered on the track (80 - 15)
            top: handleY - 15,
            child: Image.asset(
              'assets/images/chip_stack.png',
              width: 32,
              height: 30,
            ),
          ),

          // Draggable overlay area
          Positioned(
            left: 60,
            top: trackTop - 10,
            width: 44,
            height: trackHeight + 20,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                double dragY = details.localPosition.dy.clamp(0.0, trackHeight);
                double pct = 1.0 - (dragY / trackHeight);
                setState(() {
                  _raiseValue = _minRaise + (_maxRaise - _minRaise) * pct;
                  _raiseValue = (_raiseValue / 500).round() * 500;
                });
              },
              child: Container(
                color: Colors.transparent, // Capture drag anywhere near the line
              ),
            ),
          ),

          // 6. All In button at the top
          Positioned(
            left: 50,
            top: 0,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _raiseValue = _maxRaise;
                });
                _playGameSound('click1.mp3');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF162544),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.8), width: 1.2),
                ),
                child: const Text(
                  'All In',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // 7. Plus and Minus buttons on the right of the line
          Positioned(
            left: 120,
            top: trackTop + 20,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _raiseValue = math.min(_maxRaise, _raiseValue + 1500);
                });
                _playGameSound('click1.mp3');
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2E7D32),
                  border: Border.all(color: Colors.greenAccent, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 16),
              ),
            ),
          ),
          Positioned(
            left: 120,
            top: trackTop + trackHeight - 48,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _raiseValue = math.max(_minRaise, _raiseValue - 1500);
                });
                _playGameSound('click1.mp3');
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC62828),
                  border: Border.all(color: Colors.redAccent, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.remove, color: Colors.white, size: 16),
              ),
            ),
          ),

          // 8. Close X button at top right
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showRaiseSlider = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black54,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Preset Bubble (Speech-bubble style pointing right)
  Widget _buildPresetBubble(String label, double val) {
    bool isSelected = (_raiseValue - val).abs() < 500;
    return GestureDetector(
      onTap: () {
        setState(() {
          _raiseValue = val;
        });
        _playGameSound('click1.mp3');
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? Colors.cyanAccent : const Color(0xFF262626),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(-2, 0),
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 6,
                height: 6,
                color: isSelected ? Colors.cyanAccent : const Color(0xFF262626),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Selection speech bubble pointing right
  Widget _buildSelectionBubble(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(-2, 0),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 8,
              height: 8,
              color: Colors.white,
            ),
          ),
        ),
      ],
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

    bool isOwnTurn = _stateIndex == 1 || _stateIndex == 3 || _stateIndex == 4;

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

          // 2. Table and Game Controls (Centered Aspect Ratio)
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableW = constraints.maxWidth;
                  final tableH = constraints.maxHeight;
                  return Stack(
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
                      child: GestureDetector(
                        onTap: _tipDealer,
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
                            ? const AnimatedCardEntrance(
                                delay: Duration(milliseconds: 0),
                                child: PokerCard(rank: '6', suit: CardSuit.clubs, width: 44, height: 60),
                              )
                            : _buildEmptyCardPlaceholder(),
                        const SizedBox(width: 4),
                        // Card 2
                        _stateIndex >= 3
                            ? const AnimatedCardEntrance(
                                delay: Duration(milliseconds: 150),
                                child: PokerCard(rank: '4', suit: CardSuit.clubs, width: 44, height: 60),
                              )
                            : _buildEmptyCardPlaceholder(),
                        const SizedBox(width: 4),
                        // Card 3
                        _stateIndex >= 3
                            ? const AnimatedCardEntrance(
                                delay: Duration(milliseconds: 300),
                                child: PokerCard(rank: 'Q', suit: CardSuit.diamonds, width: 44, height: 60),
                              )
                            : _buildEmptyCardPlaceholder(),
                        const SizedBox(width: 4),
                        // Card 4 (Turn)
                        _stateIndex >= 5
                            ? const AnimatedCardEntrance(
                                delay: Duration(milliseconds: 0),
                                child: PokerCard(rank: 'J', suit: CardSuit.hearts, width: 44, height: 60),
                              )
                            : _buildEmptyCardPlaceholder(dotted: true),
                        const SizedBox(width: 4),
                        // Card 5 (River)
                        _stateIndex >= 5
                            ? const AnimatedCardEntrance(
                                delay: Duration(milliseconds: 150),
                                child: PokerCard(rank: '10', suit: CardSuit.clubs, width: 44, height: 60),
                              )
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
                    tableW: tableW,
                    tableH: tableH,
                    showStars: true,
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
                    tableW: tableW,
                    tableH: tableH,
                    isCircularTimer: true,
                    circularTimerVal: _opponentTimerProgress,
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
                    tableW: tableW,
                    tableH: tableH,
                    showDealerBtn: true,
                    showCrown: true,
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
                    tableW: tableW,
                    tableH: tableH,
                    isInvite: true,
                  ),

                  // 6. Own Player Section (Avatar, cards, timer, chips capsule, "15 days" bubble)
                  _buildOwnPlayerSection(ownChips, isOwnTurn),

                  // 7. Fold Button (floating bottom-left)
                  if (isOwnTurn)
                    Positioned(
                      left: 55,
                      bottom: 8,
                      child: _buildActionButton(
                        label: 'Fold',
                        gradientColors: [const Color(0xFFE53935), const Color(0xFFC62828), const Color(0xFF8E0000)],
                        onPressed: () {
                          setState(() {
                            _stateIndex = 1;
                          });
                          _startTimer();
                        },
                      ),
                    ),

                  // 8. Call / Check & Raise Buttons (floating bottom-right)
                  if (isOwnTurn)
                    Positioned(
                      right: 55,
                      bottom: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_stateIndex == 1)
                            _buildActionButton(
                              label: 'Call',
                              subtitle: '₹750',
                              gradientColors: [const Color(0xFFE53935), const Color(0xFFC62828), const Color(0xFF8E0000)],
                              onPressed: _transitionToState2,
                            ),
                          if (_stateIndex == 3)
                            _buildActionButton(
                              label: 'Check',
                              gradientColors: [const Color(0xFFE53935), const Color(0xFFC62828), const Color(0xFF8E0000)],
                              onPressed: _transitionToState4,
                            ),
                          if (_stateIndex == 4)
                            _buildActionButton(
                              label: 'Call',
                              subtitle: '₹1,500',
                              gradientColors: [const Color(0xFFE53935), const Color(0xFFC62828), const Color(0xFF8E0000)],
                              onPressed: _transitionToShowdown,
                            ),
                          const SizedBox(width: 8),
                          _buildActionButton(
                            label: 'Raise',
                            subtitle: _stateIndex == 3 ? '₹${_raiseValue.toStringAsFixed(0)}' : null,
                            icon: _stateIndex != 3 ? const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 16) : null,
                            gradientColors: [const Color(0xFF7E57C2), const Color(0xFF5E35B1), const Color(0xFF311B92)],
                            onPressed: () {
                              if (_stateIndex == 3) {
                                _transitionToState4();
                              } else {
                                setState(() {
                                  _showRaiseSlider = !_showRaiseSlider;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                  // 9. Raise Vertical Slider Overlay (floating directly inside AspectRatio)
                  if (_showRaiseSlider && isOwnTurn)
                    _buildRaiseSlider(),

                  // 10. System notification banners under the dealer
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

                  // 11. Flying Chips Animations inside the Table Stack
                  // Tip flying chips
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    alignment: _isTipAnimating ? const Alignment(0, -0.4) : const Alignment(0, 0.7),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _isTipAnimating ? 1.0 : 0.0,
                      child: Image.asset('assets/images/poker_chip.png', width: 28, height: 28),
                    ),
                  ),

                  // Bet flying chips
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutQuad,
                    alignment: _isBetAnimating ? const Alignment(0, -0.2) : const Alignment(0, 0.7),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: _isBetAnimating ? 1.0 : 0.0,
                      child: Image.asset('assets/images/chip_stack.png', width: 34, height: 26),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),

          // 11. Top Control Bar (HUD) - Full bleed
          Positioned(
            top: 8,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _playGameSound('click1.mp3');
                        Navigator.of(context).pop();
                      },
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
                Row(
                  children: [
                    _buildHUDButton(Icons.info_outline, () => _playGameSound('click1.mp3')),
                    const SizedBox(width: 8),
                    _buildHUDButton(Icons.chat_bubble_outline_rounded, () => _playGameSound('click1.mp3')),
                    const SizedBox(width: 8),
                    _buildHUDButton(Icons.group_outlined, () => _playGameSound('click1.mp3')),
                  ],
                ),
              ],
            ),
          ),

          // 12. Side "?" Help Button
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

          // Showdown / Win overlay for State 5
          if (_stateIndex == 5)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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

          // Developer debug state menu overlay
          _buildDebugMenu(),
        ],
      ),
    );
  }

  // Unified Own Player bottom-center widget stack
  Widget _buildOwnPlayerSection(String ownChips, bool isOwnTurn) {
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: 170,
          height: 140,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // 1. Avatar (at the very back)
              Positioned(
                bottom: 50,
                child: _buildAvatar(
                  imageAsset: 'assets/images/avatar_own.png',
                  isActive: isOwnTurn,
                  size: 58,
                  activeColor: Colors.yellowAccent,
                  isCircularTimer: true,
                  timerVal: _timerProgress,
                ),
              ),

              // Gift icon next to bottom-right of avatar
              Positioned(
                bottom: 52,
                left: 104,
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

              // 2. Player Hand Cards (rotated and overlapping, in front of avatar)
              Positioned(
                bottom: 42,
                child: AnimatedCardEntrance(
                  delay: const Duration(milliseconds: 600), // Dealt slightly after round start
                  child: SizedBox(
                    width: 76,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: PokerCard(
                            rank: '2',
                            suit: CardSuit.spades,
                            width: 42,
                            height: 58,
                            rotation: -0.12,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: PokerCard(
                            rank: 'K',
                            suit: CardSuit.diamonds,
                            width: 42,
                            height: 58,
                            rotation: 0.12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Own turn progress bar (horizontal orange timer bar below cards)
              if (isOwnTurn)
                Positioned(
                  bottom: 34,
                  child: Container(
                    width: 70,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _timerProgress,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB300), Color(0xFFFF3D00)],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),

              // 4. Chips Capsule (at the very bottom)
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/poker_chip.png', width: 14, height: 14),
                      const SizedBox(width: 5),
                      Text(
                        ownChips,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. "15 days" bubble to the right of the cards/chips stack
              Positioned(
                bottom: 6,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))
                    ],
                  ),
                  child: const Text(
                    '15 days',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
    return CustomPaint(
      painter: DashedRoundedRectPainter(
        color: Colors.white.withOpacity(dotted ? 0.15 : 0.4),
        strokeWidth: 1.2,
        gap: 3.0,
        dash: 4.0,
      ),
      child: Container(
        width: 44,
        height: 60,
        color: Colors.black.withOpacity(0.2),
      ),
    );
  }
}

// Custom Painter to draw dashed card slots
class DashedRoundedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;

  DashedRoundedRectPainter({
    required this.color,
    this.strokeWidth = 1.2,
    this.gap = 3.0,
    this.dash = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(4),
      ));

    final dashPath = Path();
    double distance = 0.0;
    for (final pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dash),
          Offset.zero,
        );
        distance += dash + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.dash != dash;
  }
}

// Widget to animate card deals (entrance scaling and sliding up)
class AnimatedCardEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const AnimatedCardEntrance({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<AnimatedCardEntrance> createState() => _AnimatedCardEntranceState();
}

class _AnimatedCardEntranceState extends State<AnimatedCardEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _slideAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _controller.value,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
