import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'poker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Enforce landscape orientation for a seamless immersive casino lobby
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Setup pulsing animation for the Play button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _playChipSound() {
    _player.play(AssetSource('sounds/chips_collect.mp3')).catchError((e) {
      debugPrint("Sound playing error: $e");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06180E), // Deep casino dark green
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image (Reuse the same full background or a dark felt texture)
          Opacity(
            opacity: 0.85,
            child: Image.asset(
              'assets/images/poker_bg_full.png',
              fit: BoxFit.cover,
            ),
          ),
          
          // Subtle radial dark gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.85),
                ],
                radius: 1.4,
              ),
            ),
          ),

          // 2. Main Layout
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // Top Row: Profile (Left) and Logo (Center) and Settings (Right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Profile Container
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: AssetImage('assets/images/avatar_own.png'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Mehidi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Image.asset('assets/images/poker_chip.png', width: 12, height: 12),
                                    const SizedBox(width: 3),
                                    const Text(
                                      '₹59,250',
                                      style: TextStyle(
                                        color: Colors.yellowAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Buy More "+" button
                            GestureDetector(
                              onTap: _playChipSound,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Lobby Title
                      const Text(
                        'TEEN PATTI GOLD',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontFamily: 'BebasBold',
                          fontSize: 24,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                      ),

                      // Sound/Settings buttons
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.volume_up, color: Colors.white, size: 22),
                            style: IconButton.styleFrom(backgroundColor: Colors.black45),
                            onPressed: _playChipSound,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.white, size: 22),
                            style: IconButton.styleFrom(backgroundColor: Colors.black45),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Middle Section: Large Pulsing Play Button
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.45),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFC78018)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        onPressed: () {
                          _playChipSound();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PokerScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'PLAY NOW',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'BebasBold',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(color: Colors.black54, offset: Offset(0, 1.5), blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Bottom Section: Game Mode Selection Cards
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLobbyCard(
                        title: 'PUBLIC TABLE',
                        subtitle: 'Play online with players',
                        icon: Icons.public,
                        colors: [const Color(0xFF155E38), const Color(0xFF08331C)],
                        onTap: () {
                          _playChipSound();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PokerScreen()),
                          );
                        },
                      ),
                      _buildLobbyCard(
                        title: 'PRIVATE TABLE',
                        subtitle: 'Invite your close friends',
                        icon: Icons.vpn_key,
                        colors: [const Color(0xFF5B1A8F), const Color(0xFF330C54)],
                        onTap: _playChipSound,
                      ),
                      _buildLobbyCard(
                        title: 'TOURNAMENTS',
                        subtitle: 'Compete for mega prizes',
                        icon: Icons.emoji_events,
                        colors: [const Color(0xFF9E1F1F), const Color(0xFF5E0F0F)],
                        onTap: _playChipSound,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white10),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: const Color(0xFFFFD700), size: 24),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 9,
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
}
