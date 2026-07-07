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
    Widget cardWidget = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isFaceUp ? Colors.white : const Color(0xFFB01D1D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isFaceUp ? const Color(0xFFD0D0D0) : const Color(0xFFFFFFFF),
          width: isFaceUp ? 0.8 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: const Color(0xFFFFCCCC).withOpacity(0.4),
            width: 1,
          ),
        ),
        child: CustomPaint(
          painter: _CardBackPainter(),
        ),
      ),
    );
  }

  Widget _buildFaceUp() {
    final isRed = suit == CardSuit.diamonds || suit == CardSuit.hearts;
    final color = isRed ? const Color(0xFFD32F2F) : const Color(0xFF1A1A1A);
    final suitIcon = _getSuitString();

    return Stack(
      children: [
        // Top-left Rank and Suit
        Positioned(
          top: 3,
          left: 4,
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
              Text(
                suitIcon,
                style: TextStyle(
                  color: color,
                  fontSize: height * 0.14,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        // Center Graphic
        Positioned.fill(
          top: height * 0.15,
          child: Center(
            child: _buildCenterGraphic(color),
          ),
        ),
        // Bottom-right Rank and Suit (Upside down)
        Positioned(
          bottom: 3,
          right: 4,
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
                Text(
                  suitIcon,
                  style: TextStyle(
                    color: color,
                    fontSize: height * 0.14,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getSuitString() {
    switch (suit) {
      case CardSuit.spades:
        return '♠';
      case CardSuit.diamonds:
        return '♦';
      case CardSuit.clubs:
        return '♣';
      case CardSuit.hearts:
        return '♥';
    }
  }

  Widget _buildCenterGraphic(Color color) {
    final suitIcon = _getSuitString();
    
    if (rank == 'K' || rank == 'Q' || rank == 'J') {
      return Container(
        width: width * 0.55,
        height: height * 0.55,
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3), width: 1),
          borderRadius: BorderRadius.circular(4),
          color: color.withOpacity(0.04),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Stylized court illustration lines
              CustomPaint(
                size: Size(width * 0.55, height * 0.55),
                painter: _CourtCardPainter(color, rank == 'K'),
              ),
              Text(
                rank,
                style: TextStyle(
                  color: color.withOpacity(0.2),
                  fontSize: height * 0.35,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'BebasBold',
                ),
              ),
            ],
          ),
        ),
      );
    }

    int count = int.tryParse(rank) ?? 1;
    if (count == 1) {
      return Text(
        suitIcon,
        style: TextStyle(color: color, fontSize: height * 0.32),
      );
    }
    
    // Custom layouts for numbers
    if (count == 2) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.20)),
          RotatedBox(
            quarterTurns: 2,
            child: Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.20)),
          ),
        ],
      );
    }
    
    if (count == 3) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.16)),
          Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.16)),
          RotatedBox(
            quarterTurns: 2,
            child: Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.16)),
          ),
        ],
      );
    }
    
    if (count == 4) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.15)),
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.15)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RotatedBox(quarterTurns: 2, child: Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.15))),
              RotatedBox(quarterTurns: 2, child: Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.15))),
            ],
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
            children: [
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.14)),
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.14)),
            ],
          ),
          Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.14)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RotatedBox(quarterTurns: 2, child: Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.14))),
              RotatedBox(quarterTurns: 2, child: Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.14))),
            ],
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
            children: [
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.13)),
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.13)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.13)),
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.13)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RotatedBox(quarterTurns: 2, child: Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.13))),
              RotatedBox(quarterTurns: 2, child: Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.13))),
            ],
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
            children: [
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.12)),
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.12)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.12)),
              const SizedBox(width: 8),
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.12)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RotatedBox(quarterTurns: 2, child: Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.12))),
              RotatedBox(quarterTurns: 2, child: Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.12))),
            ],
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
            children: [
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.11)),
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.11)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.11)),
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.11)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RotatedBox(quarterTurns: 2, child: Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.11))),
              RotatedBox(quarterTurns: 2, child: Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.11))),
            ],
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
            children: [
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.10)),
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.10)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.10)),
              Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.10)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              RotatedBox(quarterTurns: 2, child: Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.10))),
              RotatedBox(quarterTurns: 2, child: Text(suitIcon, style: TextStyle(color: color, fontSize: height * 0.10))),
            ],
          ),
        ],
      );
    }

    return Text(
      suitIcon,
      style: TextStyle(
        color: color,
        fontSize: height * 0.30,
      ),
    );
  }
  }
}

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF901414)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Grid repeating pattern
    final linePaint = Paint()
      ..color = const Color(0xFFD13030).withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const int steps = 6;
    final wStep = size.width / steps;
    final hStep = size.height / steps;

    for (int i = 0; i <= steps * 2; i++) {
      // Draw diagonals
      canvas.drawLine(
        Offset(0, i * hStep - size.height),
        Offset(size.width, i * hStep),
        linePaint,
      );
      canvas.drawLine(
        Offset(size.width, i * hStep - size.height),
        Offset(0, i * hStep),
        linePaint,
      );
    }

    // Inner diamond frame
    final framePaint = Paint()
      ..color = const Color(0xFFFFE0B2).withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    final path = Path()
      ..moveTo(size.width / 2, 6)
      ..lineTo(size.width - 6, size.height / 2)
      ..lineTo(size.width / 2, size.height - 6)
      ..lineTo(6, size.height / 2)
      ..close();
    canvas.drawPath(path, framePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CourtCardPainter extends CustomPainter {
  final Color color;
  final bool isKing;

  _CourtCardPainter(this.color, this.isKing);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Draw stylized head/crown
    if (isKing) {
      // Crown
      final crownPath = Path()
        ..moveTo(size.width * 0.3, size.height * 0.35)
        ..lineTo(size.width * 0.3, size.height * 0.2)
        ..lineTo(size.width * 0.4, size.height * 0.28)
        ..lineTo(size.width * 0.5, size.height * 0.16)
        ..lineTo(size.width * 0.6, size.height * 0.28)
        ..lineTo(size.width * 0.7, size.height * 0.2)
        ..lineTo(size.width * 0.7, size.height * 0.35)
        ..close();
      canvas.drawPath(crownPath, paint);

      // Face/Body
      canvas.drawOval(
        Rect.fromLTWH(size.width * 0.35, size.height * 0.35, size.width * 0.3, size.height * 0.35),
        paint,
      );
      // Sword/Staff line
      canvas.drawLine(
        Offset(size.width * 0.25, size.height * 0.25),
        Offset(size.width * 0.25, size.height * 0.8),
        paint,
      );
    } else {
      // Queen Crown/Hair
      final hairPath = Path()
        ..moveTo(size.width * 0.35, size.height * 0.3)
        ..quadraticBezierTo(size.width * 0.5, size.height * 0.18, size.width * 0.65, size.height * 0.3)
        ..lineTo(size.width * 0.65, size.height * 0.4)
        ..quadraticBezierTo(size.width * 0.5, size.height * 0.45, size.width * 0.35, size.height * 0.4)
        ..close();
      canvas.drawPath(hairPath, paint);

      // Queen Face/Body
      canvas.drawOval(
        Rect.fromLTWH(size.width * 0.38, size.height * 0.38, size.width * 0.24, size.height * 0.32),
        paint,
      );
      // Flower staff
      canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.4), 3, paint);
      canvas.drawLine(
        Offset(size.width * 0.25, size.height * 0.4),
        Offset(size.width * 0.25, size.height * 0.85),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
