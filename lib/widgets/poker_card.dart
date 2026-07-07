import 'package:flutter/material.dart';

enum CardSuit { spades, diamonds, clubs, hearts }

class PokerCard extends StatelessWidget {
  final String rank;
  final CardSuit suit;
  final bool isFaceUp;
  final double width;
  final double height;
  final double rotation; // In radians

  const PokerCard({
    super.key,
    required this.rank,
    required this.suit,
    this.isFaceUp = true,
    this.width = 54,
    this.height = 74,
    this.rotation = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardWidget = SizedBox(
      width: width,
      height: height,
      child: isFaceUp ? _buildFaceUp() : _buildFaceDown(),
    );

    if (rotation != 0.0) {
      cardWidget = Transform.rotate(
        angle: rotation,
        alignment: Alignment.center,
        child: cardWidget,
      );
    }

    return cardWidget;
  }

  Widget _buildFaceDown() {
    return Image.asset(
      'assets/images/card_back_red_60.png',
      fit: BoxFit.fill,
    );
  }

  Widget _buildFaceUp() {
    final isRed = suit == CardSuit.diamonds || suit == CardSuit.hearts;
    final color = isRed ? const Color(0xFFD32F2F) : const Color(0xFF1A1A1A);
    final String suitAsset = _getSuitAsset();

    return Stack(
      children: [
        // 1. Card Template Background
        Positioned.fill(
          child: Image.asset(
            'assets/images/card_front_60.png',
            fit: BoxFit.fill,
          ),
        ),

        // 2. Top-Left Rank & Small Suit
        Positioned(
          top: height * 0.05,
          left: width * 0.07,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                rank,
                style: TextStyle(
                  color: color,
                  fontSize: height * 0.20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'BebasBold',
                  height: 0.9,
                ),
              ),
              const SizedBox(height: 1),
              Image.asset(
                suitAsset,
                width: width * 0.16,
                height: width * 0.16,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),

        // 3. Center Graphic (Grids for numbers, full-size images for J, Q, K)
        Positioned.fill(
          top: height * 0.14,
          bottom: height * 0.14,
          left: width * 0.18,
          right: width * 0.18,
          child: Center(
            child: _buildCenterGraphic(color, suitAsset),
          ),
        ),

        // 4. Bottom-Right Rank & Small Suit (Rotated 180 degrees)
        Positioned(
          bottom: height * 0.05,
          right: width * 0.07,
          child: RotatedBox(
            quarterTurns: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  rank,
                  style: TextStyle(
                    color: color,
                    fontSize: height * 0.20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'BebasBold',
                    height: 0.9,
                  ),
                ),
                const SizedBox(height: 1),
                Image.asset(
                  suitAsset,
                  width: width * 0.16,
                  height: width * 0.16,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getSuitAsset() {
    switch (suit) {
      case CardSuit.spades:
        return 'assets/images/spades.png';
      case CardSuit.diamonds:
        return 'assets/images/diamond.png';
      case CardSuit.clubs:
        return 'assets/images/club.png';
      case CardSuit.hearts:
        return 'assets/images/heart.png';
    }
  }

  Widget _buildCenterGraphic(Color color, String suitAsset) {
    if (rank == 'J') {
      return Image.asset('assets/images/jack.png', fit: BoxFit.contain);
    }
    if (rank == 'Q') {
      return Image.asset('assets/images/queen.png', fit: BoxFit.contain);
    }
    if (rank == 'K') {
      return Image.asset('assets/images/king.png', fit: BoxFit.contain);
    }

    int count = int.tryParse(rank) ?? 1;
    if (count == 1) {
      return Image.asset(
        suitAsset,
        width: width * 0.40,
        height: height * 0.40,
        fit: BoxFit.contain,
      );
    }

    // Helper to build suit image widget
    Widget suitImg(double sizeFactor, {bool rotated = false}) {
      Widget img = Image.asset(
        suitAsset,
        width: width * sizeFactor,
        height: width * sizeFactor,
        fit: BoxFit.contain,
      );
      if (rotated) {
        return RotatedBox(quarterTurns: 2, child: img);
      }
      return img;
    }

    if (count == 2) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          suitImg(0.20),
          suitImg(0.20, rotated: true),
        ],
      );
    }

    if (count == 3) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          suitImg(0.18),
          suitImg(0.18),
          suitImg(0.18, rotated: true),
        ],
      );
    }

    if (count == 4) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.16), suitImg(0.16)],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.16, rotated: true), suitImg(0.16, rotated: true)],
          ),
        ],
      );
    }

    if (count == 5) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.15), suitImg(0.15)],
          ),
          suitImg(0.15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.15, rotated: true), suitImg(0.15, rotated: true)],
          ),
        ],
      );
    }

    if (count == 6) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.14), suitImg(0.14)],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.14), suitImg(0.14)],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.14, rotated: true), suitImg(0.14, rotated: true)],
          ),
        ],
      );
    }

    if (count == 7) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.13), suitImg(0.13)],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              suitImg(0.13),
              const SizedBox(width: 8),
              suitImg(0.13),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.13, rotated: true), suitImg(0.13, rotated: true)],
          ),
        ],
      );
    }

    if (count == 8) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.12), suitImg(0.12)],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.12), suitImg(0.12)],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.12, rotated: true), suitImg(0.12, rotated: true)],
          ),
        ],
      );
    }

    if (count == 9 || count == 10) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.11), suitImg(0.11)],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.11), suitImg(0.11)],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [suitImg(0.11, rotated: true), suitImg(0.11, rotated: true)],
          ),
        ],
      );
    }

    return suitImg(0.35);
  }
}
