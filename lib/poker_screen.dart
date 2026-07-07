import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'widgets/poker_card.dart';

// --- ENUMS & HELPERS ---
enum GameMode { demo, freePlay }

class CardModel {
  final String rank;
  final CardSuit suit;

  CardModel(this.rank, this.suit);

  int get rankValue {
    switch (rank) {
      case 'J': return 11;
      case 'Q': return 12;
      case 'K': return 13;
      case 'A': return 14;
      default: return int.parse(rank);
    }
  }

  String get suitSymbol {
    switch (suit) {
      case CardSuit.spades: return '♠';
      case CardSuit.diamonds: return '♦';
      case CardSuit.clubs: return '♣';
      case CardSuit.hearts: return '♥';
    }
  }

  @override
  String toString() => '$rank$suitSymbol';
}

class HandScore implements Comparable<HandScore> {
  final int category; // 0: High Card, 1: Pair, 2: Two Pair, 3: Three of Kind, 4: Straight, 5: Flush, 6: Full House, 7: Four of Kind, 8: Straight Flush, 9: Royal Flush
  final List<int> values; // Ranks sorted by frequency first, then value

  HandScore(this.category, this.values);

  @override
  int compareTo(HandScore other) {
    if (category != other.category) {
      return category.compareTo(other.category);
    }
    for (int i = 0; i < values.length; i++) {
      if (i >= other.values.length) return 1;
      int cmp = values[i].compareTo(other.values[i]);
      if (cmp != 0) return cmp;
    }
    return 0;
  }

  String get categoryName {
    switch (category) {
      case 9: return 'ROYAL FLUSH';
      case 8: return 'STRAIGHT FLUSH';
      case 7: return 'FOUR OF A KIND';
      case 6: return 'FULL HOUSE';
      case 5: return 'FLUSH';
      case 4: return 'STRAIGHT';
      case 3: return 'THREE OF A KIND';
      case 2: return 'TWO PAIR';
      case 1: return 'ONE PAIR';
      default: return 'HIGH CARD';
    }
  }
}

// Simple Poker Evaluator
class PokerEvaluator {
  static HandScore evaluate5Cards(List<CardModel> cards) {
    cards.sort((a, b) => b.rankValue.compareTo(a.rankValue));

    bool isFlush = cards.every((c) => c.suit == cards[0].suit);

    // Check straight
    bool isStraight = false;
    List<int> straightValues = [];

    bool standardStraight = true;
    for (int i = 0; i < 4; i++) {
      if (cards[i].rankValue - cards[i + 1].rankValue != 1) {
        standardStraight = false;
        break;
      }
    }
    if (standardStraight) {
      isStraight = true;
      straightValues = cards.map((c) => c.rankValue).toList();
    } else {
      // Ace-low straight: 5, 4, 3, 2, A
      if (cards[0].rankValue == 14 &&
          cards[1].rankValue == 5 &&
          cards[2].rankValue == 4 &&
          cards[3].rankValue == 3 &&
          cards[4].rankValue == 2) {
        isStraight = true;
        straightValues = [5, 4, 3, 2, 1];
      }
    }

    // Count frequencies
    Map<int, int> freq = {};
    for (var c in cards) {
      freq[c.rankValue] = (freq[c.rankValue] ?? 0) + 1;
    }

    var sortedGroups = freq.entries.toList()
      ..sort((a, b) {
        int cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        return b.key.compareTo(a.key);
      });

    List<int> groupFreqs = sortedGroups.map((e) => e.value).toList();
    List<int> groupValues = sortedGroups.map((e) => e.key).toList();

    int category = 0;
    if (isStraight && isFlush) {
      if (straightValues[0] == 14) {
        category = 9; // Royal Flush
      } else {
        category = 8; // Straight Flush
      }
      return HandScore(category, straightValues);
    }

    if (groupFreqs[0] == 4) {
      category = 7;
    } else if (groupFreqs[0] == 3 && groupFreqs[1] == 2) {
      category = 6;
    } else if (isFlush) {
      category = 5;
      return HandScore(category, cards.map((c) => c.rankValue).toList());
    } else if (isStraight) {
      category = 4;
      return HandScore(category, straightValues);
    } else if (groupFreqs[0] == 3) {
      category = 3;
    } else if (groupFreqs[0] == 2 && groupFreqs[1] == 2) {
      category = 2;
    } else if (groupFreqs[0] == 2) {
      category = 1;
    } else {
      category = 0;
    }

    return HandScore(category, groupValues);
  }

  static HandScore evaluate7Cards(List<CardModel> cards7) {
    HandScore? bestScore;
    // 7 choose 5 = 21 combinations
    for (int i = 0; i < 7; i++) {
      for (int j = i + 1; j < 7; j++) {
        List<CardModel> cards5 = [];
        for (int k = 0; k < 7; k++) {
          if (k != i && k != j) {
            cards5.add(cards7[k]);
          }
        }
        HandScore score = evaluate5Cards(cards5);
        if (bestScore == null || score.compareTo(bestScore) > 0) {
          bestScore = score;
        }
      }
    }
    return bestScore ?? HandScore(0, []);
  }
}

// Flying chip helper
class FlyingChip {
  final Key key;
  final Offset start;
  final Offset end;
  final String amount;

  FlyingChip({
    required this.key,
    required this.start,
    required this.end,
    required this.amount,
  });
}

// Game Player State
class PlayerState {
  final String name;
  final String avatarAsset;
  double chips;
  double bet;
  bool isFolded;
  bool isActive;
  bool isAllIn;
  String actionText;
  List<CardModel> cards;
  bool showCards;

  PlayerState({
    required this.name,
    required this.avatarAsset,
    required this.chips,
    this.bet = 0,
    this.isFolded = false,
    this.isActive = false,
    this.isAllIn = false,
    this.actionText = '',
    this.cards = const [],
    this.showCards = false,
  });

  PlayerState clone() {
    return PlayerState(
      name: name,
      avatarAsset: avatarAsset,
      chips: chips,
      bet: bet,
      isFolded: isFolded,
      isActive: isActive,
      isAllIn: isAllIn,
      actionText: actionText,
      cards: List.from(cards),
      showCards: showCards,
    );
  }
}

// --- MAIN SCREEN ---
class PokerScreen extends StatefulWidget {
  const PokerScreen({super.key});

  @override
  State<PokerScreen> createState() => _PokerScreenState();
}

class _PokerScreenState extends State<PokerScreen> with TickerProviderStateMixin {
  GameMode _gameMode = GameMode.demo;

  // Active game states
  Map<String, PlayerState> _players = {};
  List<CardModel> _communityCards = [];
  double _pot = 0;
  String _bannerText = '';
  String _activePlayerName = '';

  // Timer and slider settings
  double _timerProgress = 1.0;
  Timer? _gameTimer;
  bool _showRaiseSlider = false;
  double _raiseValue = 10500;
  double _minRaise = 1500;
  double _maxRaise = 58500;

  // Animations
  List<FlyingChip> _flyingChips = [];
  double _dealerScale = 1.0;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // For Demo Mode Step-By-Step
  int _demoStep = 0;
  bool _isAutoPlaying = false;
  Timer? _autoPlayTimer;

  // For Free Play Mode
  List<CardModel> _deck = [];
  int _freePlayDealerIndex = 0; // Rotates dealer
  int _activeSeatIndex = 0;
  double _currentCallAmount = 0;
  String _roundPhase = 'PreFlop'; // PreFlop, Flop, Turn, River, Showdown

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 4.0, end: 16.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _initializeGame();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _autoPlayTimer?.cancel();
    _glowController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _playGameSound(String filename) {
    final player = AudioPlayer();
    player.play(AssetSource('sounds/$filename')).then((_) {
      Future.delayed(const Duration(seconds: 4), () => player.dispose());
    }).catchError((e) {
      debugPrint("Audio play error: $e");
    });
  }

  void _initializeGame() {
    _gameTimer?.cancel();
    _autoPlayTimer?.cancel();
    _isAutoPlaying = false;
    _flyingChips.clear();

    if (_gameMode == GameMode.demo) {
      _setupDemoHand();
    } else {
      _startNewFreePlayHand();
    }
  }

  // --- DEMO HAND DATA & CONFIGURATION ---
  void _setupDemoHand() {
    setState(() {
      _demoStep = 0;
      _pot = 0;
      _bannerText = 'MXPLAYER has joined the Table.';
      _activePlayerName = '';
      _communityCards = [];
      _showRaiseSlider = false;

      _players = {
        'Mehidi': PlayerState(
          name: 'Mehidi',
          avatarAsset: 'assets/images/avatar_own.png',
          chips: 136000,
          cards: [
            CardModel('A', CardSuit.spades),
            CardModel('7', CardSuit.spades),
          ],
          showCards: true,
        ),
        'Guest_6187': PlayerState(
          name: 'Guest_6187',
          avatarAsset: 'assets/images/avatar_left1.png',
          chips: 62000,
          cards: [
            CardModel('9', CardSuit.diamonds),
            CardModel('8', CardSuit.diamonds),
          ],
        ),
        'MXPLAYER': PlayerState(
          name: 'MXPLAYER',
          avatarAsset: 'assets/images/avatar_right1.png',
          chips: 98000,
          cards: [
            CardModel('10', CardSuit.clubs),
            CardModel('K', CardSuit.hearts),
          ],
        ),
        'SHAHZAIB': PlayerState(
          name: 'SHAHZAIB',
          avatarAsset: 'assets/images/avatar_right2.png',
          chips: 98000,
          cards: [
            CardModel('7', CardSuit.hearts),
            CardModel('8', CardSuit.clubs),
          ],
        ),
      };
    });

    _playGameSound('click1.mp3');
    _startDemoTimer();
  }

  void _startDemoTimer() {
    _gameTimer?.cancel();
    _timerProgress = 1.0;
    _gameTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        if (_activePlayerName.isNotEmpty) {
          _timerProgress -= 0.01;
          if (_timerProgress <= 0) {
            _timerProgress = 1.0;
            if (_isAutoPlaying) {
              _advanceDemoStep();
            }
          }
        } else {
          _timerProgress = 1.0;
        }
      });
    });
  }

  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlaying = !_isAutoPlaying;
      if (_isAutoPlaying) {
        _playGameSound('click1.mp3');
        _runAutoPlayLoop();
      } else {
        _autoPlayTimer?.cancel();
      }
    });
  }

  void _runAutoPlayLoop() {
    _autoPlayTimer?.cancel();
    if (!_isAutoPlaying) return;

    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (!mounted || !_isAutoPlaying) {
        timer.cancel();
        return;
      }
      if (_activePlayerName != 'Mehidi') {
        _advanceDemoStep();
      }
    });
  }

  void _nudgeDealer() {
    setState(() {
      _dealerScale = 1.12;
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _dealerScale = 1.0);
    });
  }

  void _animateChipsBet(String playerName, double amount, bool toPot) {
    final tableW = MediaQuery.of(context).size.width;
    final tableH = MediaQuery.of(context).size.height;

    Offset startOffset;
    switch (playerName) {
      case 'Mehidi': startOffset = Offset(tableW / 2, tableH * 0.76); break;
      case 'Guest_6187': startOffset = Offset(tableW * 0.16, tableH * 0.62); break;
      case 'MXPLAYER': startOffset = Offset(tableW * 0.78, tableH * 0.28); break;
      case 'SHAHZAIB': startOffset = Offset(tableW * 0.84, tableH * 0.62); break;
      default: startOffset = Offset(tableW / 2, tableH * 0.2);
    }

    Offset endOffset = Offset(tableW / 2, tableH * 0.28);

    if (!toPot) {
      // Pot to player
      Offset temp = startOffset;
      startOffset = endOffset;
      endOffset = temp;
    }

    final key = UniqueKey();
    setState(() {
      _flyingChips.add(FlyingChip(
        key: key,
        start: startOffset,
        end: startOffset,
        amount: '₹${amount.toStringAsFixed(0)}',
      ));
    });

    _playGameSound('chips_jiggle.mp3');

    // Trigger animation
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      setState(() {
        int idx = _flyingChips.indexWhere((c) => c.key == key);
        if (idx != -1) {
          _flyingChips[idx] = FlyingChip(
            key: key,
            start: startOffset,
            end: endOffset,
            amount: '₹${amount.toStringAsFixed(0)}',
          );
        }
      });
    });

    // Remove
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted) return;
      setState(() {
        _flyingChips.removeWhere((c) => c.key == key);
      });
    });
  }

  void _advanceDemoStep() {
    if (_gameMode != GameMode.demo) return;
    setState(() {
      _demoStep++;
      if (_demoStep > 27) {
        _demoStep = 0;
        _setupDemoHand();
        return;
      }

      switch (_demoStep) {
        case 1:
          _bannerText = 'Starting game';
          _playGameSound('card_shuffle.mp3');
          break;
        case 2:
          _bannerText = 'Collecting Blinds';
          _players['Mehidi']!.chips = 135000;
          _players['Mehidi']!.bet = 1000;
          _players['Mehidi']!.actionText = 'Small Blind';
          
          _players['Guest_6187']!.chips = 60000;
          _players['Guest_6187']!.bet = 2000;
          _players['Guest_6187']!.actionText = 'Big Blind';

          _pot = 3000;
          _animateChipsBet('Mehidi', 1000, true);
          _animateChipsBet('Guest_6187', 2000, true);
          break;
        case 3:
          _bannerText = 'Deal Cards';
          _nudgeDealer();
          _playGameSound('card_deal.mp3');
          _activePlayerName = 'MXPLAYER';
          _players['MXPLAYER']!.isActive = true;
          break;
        case 4:
          _bannerText = 'MXPLAYER raises ₹10,000';
          _players['MXPLAYER']!.chips = 88000;
          _players['MXPLAYER']!.bet = 10000;
          _players['MXPLAYER']!.actionText = 'Raise';
          _players['MXPLAYER']!.isActive = false;
          _pot = 13000;
          _animateChipsBet('MXPLAYER', 10000, true);
          
          _activePlayerName = 'SHAHZAIB';
          _players['SHAHZAIB']!.isActive = true;
          break;
        case 5:
          _bannerText = 'SHAHZAIB went All In with ₹5,880';
          _players['SHAHZAIB']!.chips = 0;
          _players['SHAHZAIB']!.bet = 5880;
          _players['SHAHZAIB']!.isAllIn = true;
          _players['SHAHZAIB']!.actionText = 'All In';
          _players['SHAHZAIB']!.isActive = false;
          _pot = 18880;
          _animateChipsBet('SHAHZAIB', 5880, true);

          _activePlayerName = 'Mehidi';
          _players['Mehidi']!.isActive = true;
          _timerProgress = 1.0;
          _showRaiseSlider = true; // Slider automatically opens as in video
          _raiseValue = 21000;
          _playGameSound('your_turn.mp3');
          break;
        // User action raise ₹21,000 handled by own button call
        case 6:
          _bannerText = 'Mehidi raises ₹21,000';
          _players['Mehidi']!.chips = 114000;
          _players['Mehidi']!.bet = 21000;
          _players['Mehidi']!.actionText = 'Raise';
          _players['Mehidi']!.isActive = false;
          _pot = 39880;
          _showRaiseSlider = false;
          _animateChipsBet('Mehidi', 20000, true);

          _activePlayerName = 'Guest_6187';
          _players['Guest_6187']!.isActive = true;
          break;
        case 7:
          _bannerText = 'Guest_6187 calls ₹20,000';
          _players['Guest_6187']!.chips = 40000;
          _players['Guest_6187']!.bet = 22000;
          _players['Guest_6187']!.actionText = 'Call';
          _players['Guest_6187']!.isActive = false;
          _pot = 59880;
          _animateChipsBet('Guest_6187', 20000, true);

          _activePlayerName = 'MXPLAYER';
          _players['MXPLAYER']!.isActive = true;
          break;
        case 8:
          _bannerText = 'MXPLAYER calls ₹12,000';
          _players['MXPLAYER']!.chips = 76000;
          _players['MXPLAYER']!.bet = 22000;
          _players['MXPLAYER']!.actionText = 'Call';
          _players['MXPLAYER']!.isActive = false;
          _pot = 71880;
          _animateChipsBet('MXPLAYER', 12000, true);

          _activePlayerName = '';
          break;
        case 9:
          _bannerText = 'Dealing the Flop';
          _players['Mehidi']!.bet = 0;
          _players['Mehidi']!.actionText = '';
          _players['Guest_6187']!.bet = 0;
          _players['Guest_6187']!.actionText = '';
          _players['MXPLAYER']!.bet = 0;
          _players['MXPLAYER']!.actionText = '';
          _players['SHAHZAIB']!.bet = 0;
          _players['SHAHZAIB']!.actionText = '';

          _nudgeDealer();
          _playGameSound('card_deal.mp3');
          _communityCards = [
            CardModel('5', CardSuit.diamonds),
            CardModel('2', CardSuit.hearts),
            CardModel('9', CardSuit.clubs),
          ];
          break;
        case 10:
          _bannerText = 'Your Turn';
          _activePlayerName = 'Mehidi';
          _players['Mehidi']!.isActive = true;
          _timerProgress = 1.0;
          _playGameSound('your_turn.mp3');
          break;
        // User action flop raise ₹4,000
        case 11:
          _bannerText = 'Mehidi raises ₹4,000';
          _players['Mehidi']!.chips = 110000;
          _players['Mehidi']!.bet = 4000;
          _players['Mehidi']!.actionText = 'Raise';
          _players['Mehidi']!.isActive = false;
          _pot = 75880;
          _animateChipsBet('Mehidi', 4000, true);

          _activePlayerName = 'Guest_6187';
          _players['Guest_6187']!.isActive = true;
          break;
        case 12:
          _bannerText = 'Guest_6187 calls ₹4,000';
          _players['Guest_6187']!.chips = 36000;
          _players['Guest_6187']!.bet = 4000;
          _players['Guest_6187']!.actionText = 'Call';
          _players['Guest_6187']!.isActive = false;
          _pot = 79880;
          _animateChipsBet('Guest_6187', 4000, true);

          _activePlayerName = 'MXPLAYER';
          _players['MXPLAYER']!.isActive = true;
          break;
        case 13:
          _bannerText = 'MXPLAYER calls ₹4,000';
          _players['MXPLAYER']!.chips = 72000;
          _players['MXPLAYER']!.bet = 4000;
          _players['MXPLAYER']!.actionText = 'Call';
          _players['MXPLAYER']!.isActive = false;
          _pot = 83880;
          _animateChipsBet('MXPLAYER', 4000, true);

          _activePlayerName = '';
          break;
        case 14:
          _bannerText = 'Dealing the Turn';
          _players['Mehidi']!.bet = 0;
          _players['Mehidi']!.actionText = '';
          _players['Guest_6187']!.bet = 0;
          _players['Guest_6187']!.actionText = '';
          _players['MXPLAYER']!.bet = 0;
          _players['MXPLAYER']!.actionText = '';

          _nudgeDealer();
          _playGameSound('card_deal.mp3');
          _communityCards.add(CardModel('J', CardSuit.hearts));
          break;
        case 15:
          _bannerText = 'Your Turn';
          _activePlayerName = 'Mehidi';
          _players['Mehidi']!.isActive = true;
          _timerProgress = 1.0;
          _playGameSound('your_turn.mp3');
          break;
        // User action Check
        case 16:
          _bannerText = 'Mehidi checks';
          _players['Mehidi']!.actionText = 'Check';
          _players['Mehidi']!.isActive = false;
          
          _activePlayerName = 'Guest_6187';
          _players['Guest_6187']!.isActive = true;
          break;
        case 17:
          _bannerText = 'Guest_6187 has Folded';
          _players['Guest_6187']!.isFolded = true;
          _players['Guest_6187']!.actionText = 'Fold';
          _players['Guest_6187']!.isActive = false;

          _activePlayerName = 'MXPLAYER';
          _players['MXPLAYER']!.isActive = true;
          break;
        case 18:
          _bannerText = 'MXPLAYER raises ₹4,000';
          _players['MXPLAYER']!.chips = 68000;
          _players['MXPLAYER']!.bet = 4000;
          _players['MXPLAYER']!.actionText = 'Raise';
          _players['MXPLAYER']!.isActive = false;
          _pot = 87880;
          _animateChipsBet('MXPLAYER', 4000, true);

          _activePlayerName = 'Mehidi';
          _players['Mehidi']!.isActive = true;
          _timerProgress = 1.0;
          _playGameSound('your_turn.mp3');
          break;
        // User action Call ₹4,000
        case 19:
          _bannerText = 'Mehidi calls ₹4,000';
          _players['Mehidi']!.chips = 106000;
          _players['Mehidi']!.bet = 4000;
          _players['Mehidi']!.actionText = 'Call';
          _players['Mehidi']!.isActive = false;
          _pot = 91880;
          _animateChipsBet('Mehidi', 4000, true);

          _activePlayerName = '';
          break;
        case 20:
          _bannerText = 'Dealing the River';
          _players['Mehidi']!.bet = 0;
          _players['Mehidi']!.actionText = '';
          _players['MXPLAYER']!.bet = 0;
          _players['MXPLAYER']!.actionText = '';

          _nudgeDealer();
          _playGameSound('card_deal.mp3');
          _communityCards.add(CardModel('5', CardSuit.hearts));
          break;
        case 21:
          _bannerText = 'Your Turn';
          _activePlayerName = 'Mehidi';
          _players['Mehidi']!.isActive = true;
          _timerProgress = 1.0;
          _playGameSound('your_turn.mp3');
          break;
        // User Check River
        case 22:
          _bannerText = 'Mehidi checks';
          _players['Mehidi']!.actionText = 'Check';
          _players['Mehidi']!.isActive = false;

          _activePlayerName = 'MXPLAYER';
          _players['MXPLAYER']!.isActive = true;
          break;
        case 23:
          _bannerText = 'MXPLAYER raises ₹16,000';
          _players['MXPLAYER']!.chips = 52000;
          _players['MXPLAYER']!.bet = 16000;
          _players['MXPLAYER']!.actionText = 'Raise';
          _players['MXPLAYER']!.isActive = false;
          _pot = 107880;
          _animateChipsBet('MXPLAYER', 16000, true);

          _activePlayerName = 'Mehidi';
          _players['Mehidi']!.isActive = true;
          _timerProgress = 1.0;
          _playGameSound('your_turn.mp3');
          break;
        // User folds
        case 24:
          _bannerText = 'Mehidi Folded';
          _players['Mehidi']!.isFolded = true;
          _players['Mehidi']!.actionText = 'Fold';
          _players['Mehidi']!.isActive = false;
          _activePlayerName = '';
          break;
        case 25:
          _bannerText = 'Showdown';
          _players['MXPLAYER']!.showCards = true;
          _players['SHAHZAIB']!.showCards = true;
          _players['MXPLAYER']!.actionText = 'ONE PAIR';
          _players['SHAHZAIB']!.actionText = 'ONE PAIR';
          break;
        case 26:
          _bannerText = 'MXPLAYER wins Main Pot (₹1.07 L)';
          _animateChipsBet('MXPLAYER', _pot, false);
          _playGameSound('winner.mp3');
          _playGameSound('chips_collect.mp3');
          break;
        case 27:
          _players['MXPLAYER']!.chips = 159880;
          _pot = 0;
          _bannerText = 'Hand Complete. Restarting...';
          break;
      }
    });
  }

  // User Actions during Demo Mode
  void _executeDemoUserAction(String action) {
    if (_gameMode != GameMode.demo || _activePlayerName != 'Mehidi') return;

    if (_demoStep == 5 && action == 'Raise') {
      _advanceDemoStep(); // Mehidi raises ₹21,000
    } else if (_demoStep == 10 && action == 'Raise') {
      _advanceDemoStep(); // Mehidi raises ₹4,000 Flop
    } else if (_demoStep == 15 && action == 'Check') {
      _advanceDemoStep(); // Mehidi checks Turn
    } else if (_demoStep == 18 && action == 'Call') {
      _advanceDemoStep(); // Mehidi calls Turn
    } else if (_demoStep == 21 && action == 'Check') {
      _advanceDemoStep(); // Mehidi checks River
    } else if (_demoStep == 23 && action == 'Fold') {
      _advanceDemoStep(); // Mehidi Folds River
    } else {
      // Fallback: advance anyway but output click
      _playGameSound('click1.mp3');
      _advanceDemoStep();
    }
  }

  // --- FREE PLAY GAME ENGINE LOGIC ---
  void _startNewFreePlayHand() {
    setState(() {
      _roundPhase = 'PreFlop';
      _communityCards = [];
      _showRaiseSlider = false;
      _pot = 0;
      _bannerText = 'Dealing cards...';
      _currentCallAmount = 2000;

      // Build & Shuffle Deck
      _deck = [];
      for (var suit in CardSuit.values) {
        for (var rank in ['2','3','4','5','6','7','8','9','10','J','Q','K','A']) {
          _deck.add(CardModel(rank, suit));
        }
      }
      _deck.shuffle();

      // Initialize players
      _players = {
        'Mehidi': PlayerState(
          name: 'Mehidi',
          avatarAsset: 'assets/images/avatar_own.png',
          chips: 100000,
          cards: [_drawCard(), _drawCard()],
          showCards: true,
        ),
        'Guest_6187': PlayerState(
          name: 'Guest_6187',
          avatarAsset: 'assets/images/avatar_left1.png',
          chips: 100000,
          cards: [_drawCard(), _drawCard()],
        ),
        'MXPLAYER': PlayerState(
          name: 'MXPLAYER',
          avatarAsset: 'assets/images/avatar_right1.png',
          chips: 100000,
          cards: [_drawCard(), _drawCard()],
        ),
        'SHAHZAIB': PlayerState(
          name: 'SHAHZAIB',
          avatarAsset: 'assets/images/avatar_right2.png',
          chips: 100000,
          cards: [_drawCard(), _drawCard()],
        ),
      };

      // Collect Blinds
      _freePlayDealerIndex = (_freePlayDealerIndex + 1) % 4;
      int sbIndex = (_freePlayDealerIndex + 1) % 4;
      int bbIndex = (_freePlayDealerIndex + 2) % 4;

      List<String> playerKeys = _players.keys.toList();
      String sbPlayer = playerKeys[sbIndex];
      String bbPlayer = playerKeys[bbIndex];

      _players[sbPlayer]!.bet = 1000;
      _players[sbPlayer]!.chips -= 1000;
      _players[sbPlayer]!.actionText = 'Small Blind';
      _animateChipsBet(sbPlayer, 1000, true);

      _players[bbPlayer]!.bet = 2000;
      _players[bbPlayer]!.chips -= 2000;
      _players[bbPlayer]!.actionText = 'Big Blind';
      _animateChipsBet(bbPlayer, 2000, true);

      _pot = 3000;

      // Active player starts left of Big Blind
      _activeSeatIndex = (_freePlayDealerIndex + 3) % 4;
      _activePlayerName = playerKeys[_activeSeatIndex];
      
      for (var p in _players.values) {
        p.isActive = (p.name == _activePlayerName);
      }
    });

    _playGameSound('card_shuffle.mp3');
    _nudgeDealer();
    _playGameSound('card_deal.mp3');
    
    _startFreePlayTimer();
    
    // If bot starts, trigger bot action
    if (_activePlayerName != 'Mehidi') {
      Future.delayed(const Duration(milliseconds: 2000), () => _executeBotAction());
    } else {
      _playGameSound('your_turn.mp3');
    }
  }

  CardModel _drawCard() {
    return _deck.removeLast();
  }

  void _startFreePlayTimer() {
    _gameTimer?.cancel();
    _timerProgress = 1.0;
    _gameTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted) return;
      setState(() {
        if (_activePlayerName.isNotEmpty) {
          _timerProgress -= 0.015;
          if (_timerProgress < 0.3) {
            // Optional ticking sound can go here
          }
          if (_timerProgress <= 0) {
            _timerProgress = 1.0;
            _autoTimeoutActivePlayer();
          }
        }
      });
    });
  }

  void _autoTimeoutActivePlayer() {
    if (_activePlayerName == 'Mehidi') {
      _executeFreePlayUserAction('Fold');
    } else {
      _executeBotAction();
    }
  }

  void _nextFreePlayTurn() {
    // Check if round is over (everyone checked or matched highest bet)
    bool roundComplete = _checkRoundComplete();
    if (roundComplete) {
      _advanceRoundPhase();
      return;
    }

    // Find next active player
    List<String> playerKeys = _players.keys.toList();
    int searchIndex = _activeSeatIndex;
    while (true) {
      searchIndex = (searchIndex + 1) % 4;
      String nextPlayer = playerKeys[searchIndex];
      
      if (!_players[nextPlayer]!.isFolded && !_players[nextPlayer]!.isAllIn) {
        setState(() {
          _activeSeatIndex = searchIndex;
          _activePlayerName = nextPlayer;
          _timerProgress = 1.0;
          
          for (var p in _players.values) {
            p.isActive = (p.name == _activePlayerName);
          }
        });
        break;
      }
    }

    if (_activePlayerName == 'Mehidi') {
      _playGameSound('your_turn.mp3');
    } else {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted && _activePlayerName != 'Mehidi') {
          _executeBotAction();
        }
      });
    }
  }

  bool _checkRoundComplete() {
    List<PlayerState> activePlayers = _players.values.where((p) => !p.isFolded && !p.isAllIn).toList();
    if (activePlayers.length <= 1) return true;

    // Check if everyone has matched the highest bet
    double maxBet = _players.values.map((p) => p.bet).reduce(math.max);
    for (var p in _players.values) {
      if (!p.isFolded && !p.isAllIn && p.bet < maxBet) {
        return false;
      }
    }
    return true;
  }

  void _advanceRoundPhase() {
    // Put all player bets into the main pot
    setState(() {
      for (var p in _players.values) {
        p.bet = 0;
        p.actionText = '';
      }
    });

    if (_roundPhase == 'PreFlop') {
      setState(() {
        _roundPhase = 'Flop';
        _communityCards = [_drawCard(), _drawCard(), _drawCard()];
        _bannerText = 'Dealing the Flop';
      });
      _nudgeDealer();
      _playGameSound('card_deal.mp3');
    } else if (_roundPhase == 'Flop') {
      setState(() {
        _roundPhase = 'Turn';
        _communityCards.add(_drawCard());
        _bannerText = 'Dealing the Turn';
      });
      _nudgeDealer();
      _playGameSound('card_deal.mp3');
    } else if (_roundPhase == 'Flop' || _roundPhase == 'Turn') {
      setState(() {
        _roundPhase = 'River';
        _communityCards.add(_drawCard());
        _bannerText = 'Dealing the River';
      });
      _nudgeDealer();
      _playGameSound('card_deal.mp3');
    } else if (_roundPhase == 'River') {
      _executeFreePlayShowdown();
      return;
    }

    // Reset active player to small blind or first active clockwise of dealer
    List<String> playerKeys = _players.keys.toList();
    int searchIndex = _freePlayDealerIndex;
    while (true) {
      searchIndex = (searchIndex + 1) % 4;
      String nextPlayer = playerKeys[searchIndex];
      if (!_players[nextPlayer]!.isFolded && !_players[nextPlayer]!.isAllIn) {
        setState(() {
          _activeSeatIndex = searchIndex;
          _activePlayerName = nextPlayer;
          _timerProgress = 1.0;
          _currentCallAmount = 0;

          for (var p in _players.values) {
            p.isActive = (p.name == _activePlayerName);
          }
        });
        break;
      }
    }

    if (_activePlayerName == 'Mehidi') {
      _playGameSound('your_turn.mp3');
    } else {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted && _activePlayerName != 'Mehidi') {
          _executeBotAction();
        }
      });
    }
  }

  void _executeBotAction() {
    if (_gameMode != GameMode.freePlay || _activePlayerName == 'Mehidi') return;

    PlayerState bot = _players[_activePlayerName]!;
    
    // Evaluate strength roughly
    double maxBet = _players.values.map((p) => p.bet).reduce(math.max);
    double toCall = maxBet - bot.bet;

    // Simple AI decision
    String action = 'Check';
    double betAmt = 0;

    if (toCall > 0) {
      // Need to Call or Fold
      int scoreVal = _evaluateBotHandStrength(bot);
      if (scoreVal >= 2 || (scoreVal >= 1 && toCall <= bot.chips * 0.2)) {
        action = 'Call';
        betAmt = toCall;
      } else {
        action = 'Fold';
      }
    } else {
      // Can Check or Raise
      int scoreVal = _evaluateBotHandStrength(bot);
      if (scoreVal >= 3 && bot.chips > 4000) {
        action = 'Raise';
        betAmt = 4000;
      } else {
        action = 'Check';
      }
    }

    setState(() {
      bot.isActive = false;
      if (action == 'Fold') {
        bot.isFolded = true;
        bot.actionText = 'Fold';
        _bannerText = '${bot.name} Folded';
      } else if (action == 'Check') {
        bot.actionText = 'Check';
        _bannerText = '${bot.name} Checks';
      } else if (action == 'Call') {
        bot.chips -= betAmt;
        bot.bet += betAmt;
        _pot += betAmt;
        bot.actionText = 'Call';
        _bannerText = '${bot.name} calls ₹${betAmt.toStringAsFixed(0)}';
        _animateChipsBet(bot.name, betAmt, true);
      } else if (action == 'Raise') {
        bot.chips -= betAmt;
        bot.bet += betAmt;
        _pot += betAmt;
        _currentCallAmount = bot.bet;
        bot.actionText = 'Raise';
        _bannerText = '${bot.name} raises ₹${betAmt.toStringAsFixed(0)}';
        _animateChipsBet(bot.name, betAmt, true);
      }
    });

    _nextFreePlayTurn();
  }

  int _evaluateBotHandStrength(PlayerState bot) {
    if (_communityCards.isEmpty) {
      // Preflop: High card, Ace or pair
      if (bot.cards[0].rank == bot.cards[1].rank) return 4; // Pair
      if (bot.cards[0].rank == 'A' || bot.cards[1].rank == 'A') return 2;
      return 1;
    }
    
    // Evaluate 5, 6 or 7 cards
    List<CardModel> combined = [...bot.cards, ..._communityCards];
    HandScore score = PokerEvaluator.evaluate7Cards(combined);
    return score.category;
  }

  void _executeFreePlayUserAction(String action, [double raiseAmt = 0]) {
    if (_gameMode != GameMode.freePlay || _activePlayerName != 'Mehidi') return;

    PlayerState own = _players['Mehidi']!;
    double maxBet = _players.values.map((p) => p.bet).reduce(math.max);
    double toCall = maxBet - own.bet;

    setState(() {
      _showRaiseSlider = false;
      own.isActive = false;

      if (action == 'Fold') {
        own.isFolded = true;
        own.actionText = 'Fold';
        _bannerText = 'Mehidi Folded';
      } else if (action == 'Check') {
        own.actionText = 'Check';
        _bannerText = 'Mehidi Checks';
      } else if (action == 'Call') {
        own.chips -= toCall;
        own.bet += toCall;
        _pot += toCall;
        own.actionText = 'Call';
        _bannerText = 'Mehidi calls ₹${toCall.toStringAsFixed(0)}';
        _animateChipsBet('Mehidi', toCall, true);
      } else if (action == 'Raise') {
        double totalRaise = raiseAmt - own.bet;
        own.chips -= totalRaise;
        own.bet = raiseAmt;
        _pot += totalRaise;
        _currentCallAmount = raiseAmt;
        own.actionText = 'Raise';
        _bannerText = 'Mehidi raises to ₹${raiseAmt.toStringAsFixed(0)}';
        _animateChipsBet('Mehidi', totalRaise, true);
      }
    });

    _nextFreePlayTurn();
  }

  void _executeFreePlayShowdown() {
    _gameTimer?.cancel();
    setState(() {
      _activePlayerName = '';
      _roundPhase = 'Showdown';
      _bannerText = 'Showdown!';

      // Reveal everyone's cards and evaluate scores
      Map<String, HandScore> scores = {};
      for (var p in _players.values) {
        if (!p.isFolded) {
          p.showCards = true;
          List<CardModel> combined = [...p.cards, ..._communityCards];
          HandScore hs = PokerEvaluator.evaluate7Cards(combined);
          p.actionText = hs.categoryName;
          scores[p.name] = hs;
        }
      }

      // Determine Winner
      String winner = '';
      HandScore? bestScore;
      for (var entry in scores.entries) {
        if (bestScore == null || entry.value.compareTo(bestScore) > 0) {
          bestScore = entry.value;
          winner = entry.key;
        }
      }

      _bannerText = '$winner wins Main Pot (₹${_pot.toStringAsFixed(0)}) with ${bestScore?.categoryName}';
      _players[winner]!.chips += _pot;
      _animateChipsBet(winner, _pot, false);
    });

    _playGameSound('winner.mp3');
    _playGameSound('chips_collect.mp3');

    // Auto restart after 6 seconds
    Future.delayed(const Duration(milliseconds: 6000), () {
      if (mounted && _gameMode == GameMode.freePlay) {
        _startNewFreePlayHand();
      }
    });
  }

  // --- UI BUILDING HELPERS ---
  String _formatCurrency(double val) {
    if (val >= 100000) {
      return '₹${(val / 100000).toStringAsFixed(2)} L';
    }
    return '₹${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

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

  Widget _buildSeat({
    required PlayerState player,
    required double x,
    required double y,
    required double tableW,
    required double tableH,
    bool isInvite = false,
    bool showDealerBtn = false,
    bool showCrown = false,
    bool showStars = false,
  }) {
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

    final isFolded = player.isFolded;
    final isLeftPlayer = x < 0;

    return Positioned(
      left: left - 80,
      top: top - 65,
      width: 160,
      height: 130,
      child: Opacity(
        opacity: isFolded ? 0.6 : 1.0,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // 1. Name & Chips Column
            Positioned(
              top: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    player.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _formatCurrency(player.chips),
                    style: const TextStyle(
                      color: Colors.yellowAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Avatar
            Positioned(
              top: 30,
              child: _buildAvatar(
                imageAsset: player.avatarAsset,
                isActive: player.isActive,
                size: 46,
                isCircularTimer: true,
                timerVal: _timerProgress,
              ),
            ),

            // 3. Gift Capsule
            Positioned(
              top: 54,
              left: isLeftPlayer ? 104 : 12,
              child: Container(
                padding: const EdgeInsets.all(3.5),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 2)],
                ),
                child: const Icon(Icons.card_giftcard, color: Colors.amber, size: 11),
              ),
            ),

            // 4. Overlapping Hand Cards next to avatar
            if (!isFolded && player.cards.isNotEmpty)
              Positioned(
                top: 34,
                left: isLeftPlayer ? 106 : 8,
                child: SizedBox(
                  width: 44,
                  height: 38,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        child: PokerCard(
                          rank: player.cards[0].rank,
                          suit: player.cards[0].suit,
                          isFaceUp: player.showCards,
                          width: 22,
                          height: 32,
                          rotation: -0.15,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: PokerCard(
                          rank: player.cards[1].rank,
                          suit: player.cards[1].suit,
                          isFaceUp: player.showCards,
                          width: 22,
                          height: 32,
                          rotation: 0.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 5. Crown Decor
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

            // 6. Stars Decor
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

            // 7. Dealer Button capsule
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

            // 8. Player Action Capsule (E.g. Call ₹2,000 or All In)
            if (player.actionText.isNotEmpty || player.bet > 0)
              Positioned(
                top: 86,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isFolded
                          ? const Color(0xFFC62828)
                          : (player.actionText == 'Raise' || player.actionText == 'All In')
                              ? const Color(0xFF5E35B1)
                              : Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFolded
                            ? Colors.redAccent
                            : (player.actionText == 'Raise' || player.actionText == 'All In')
                                ? Colors.deepPurpleAccent
                                : const Color(0xFF4CAF50),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isFolded && player.bet > 0) ...[
                          Image.asset('assets/images/poker_chip.png', width: 11, height: 11),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          player.actionText.isNotEmpty
                              ? (player.bet > 0
                                  ? '${player.actionText} ₹${player.bet.toStringAsFixed(0)}'
                                  : player.actionText)
                              : '₹${player.bet.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Vertical Raise Slider UI
  Widget _buildRaiseSlider() {
    double trackHeight = 180.0;
    double trackTop = 40.0;
    double sliderWidth = 160.0;

    double pct = (_raiseValue - _minRaise) / (_maxRaise - _minRaise);
    if (pct.isNaN) pct = 0.0;
    double handleY = trackTop + trackHeight - (pct * trackHeight);

    return Positioned(
      right: 55,
      bottom: 62,
      width: sliderWidth,
      height: 290,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Line
          Positioned(
            left: 80,
            top: trackTop,
            bottom: 290 - (trackTop + trackHeight),
            child: Container(
              width: 3.2,
              color: Colors.white38,
            ),
          ),

          // 2. White Tick Marks
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

          // 3. Preset bubbles on the left
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

          // 4. Speech Bubble selection indicator
          Positioned(
            right: 86,
            top: handleY - 14,
            child: _buildSelectionBubble('₹${_raiseValue.toStringAsFixed(0)}'),
          ),

          // 5. Chip stack handle
          Positioned(
            left: 65,
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
                  if (_raiseValue > _maxRaise) _raiseValue = _maxRaise;
                  if (_raiseValue < _minRaise) _raiseValue = _minRaise;
                });
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

          // 6. All In button at top
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

          // 7. Plus/Minus adjusters
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
                ),
                child: const Icon(Icons.remove, color: Colors.white, size: 16),
              ),
            ),
          ),

          // 8. Close X Button
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

  Widget _buildSelectionBubble(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
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

  // Own player bottom-center card and chip block
  Widget _buildOwnPlayerSection(PlayerState player, bool isOwnTurn) {
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
              // 1. Avatar
              Positioned(
                bottom: 50,
                child: _buildAvatar(
                  imageAsset: player.avatarAsset,
                  isActive: isOwnTurn,
                  size: 58,
                  activeColor: Colors.yellowAccent,
                  isCircularTimer: true,
                  timerVal: _timerProgress,
                ),
              ),

              // Gift box button
              Positioned(
                bottom: 52,
                left: 106,
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

              // 2. Horizontal depleting orange timer bar below cards
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
                      widthFactor: _timerProgress.clamp(0.0, 1.0),
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

              // 3. Chips Capsule
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/poker_chip.png', width: 14, height: 14),
                      const SizedBox(width: 5),
                      Text(
                        _formatCurrency(player.chips),
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

              // 4. "15 days" banner bubble
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

  Widget _buildActionButtons(PlayerState ownPlayer, bool isOwnTurn) {
    if (!isOwnTurn) return const SizedBox.shrink();

    // Determine what is currently needed (Fold, Call, Check, Raise)
    double maxBet = _players.values.map((p) => p.bet).reduce(math.max);
    double toCall = maxBet - ownPlayer.bet;

    bool canCheck = (toCall <= 0);

    // Guide target highlights for Video Demo Mode
    bool foldHighlight = false;
    bool checkHighlight = false;
    bool callHighlight = false;
    bool raiseHighlight = false;

    if (_gameMode == GameMode.demo) {
      if (_demoStep == 5) raiseHighlight = true;
      if (_demoStep == 10) raiseHighlight = true;
      if (_demoStep == 15) checkHighlight = true;
      if (_demoStep == 18) callHighlight = true;
      if (_demoStep == 21) checkHighlight = true;
      if (_demoStep == 23) foldHighlight = true;
    }

    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Side: Fold Button
          Padding(
            padding: const EdgeInsets.only(left: 55),
            child: _buildActionButton(
              label: 'Fold',
              gradientColors: [const Color(0xFFE53935), const Color(0xFFC62828), const Color(0xFF8E0000)],
              highlight: foldHighlight,
              onPressed: () {
                if (_gameMode == GameMode.demo) {
                  _executeDemoUserAction('Fold');
                } else {
                  _executeFreePlayUserAction('Fold');
                }
              },
            ),
          ),

          // Right Side: Call / Check & Raise Buttons
          Padding(
            padding: const EdgeInsets.only(right: 55),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canCheck)
                  _buildActionButton(
                    label: 'Check',
                    gradientColors: [const Color(0xFFFF9800), const Color(0xFFF57C00), const Color(0xFFE65100)],
                    highlight: checkHighlight,
                    onPressed: () {
                      if (_gameMode == GameMode.demo) {
                        _executeDemoUserAction('Check');
                      } else {
                        _executeFreePlayUserAction('Check');
                      }
                    },
                  )
                else
                  _buildActionButton(
                    label: 'Call',
                    subtitle: '₹${toCall.toStringAsFixed(0)}',
                    gradientColors: [const Color(0xFF4CAF50), const Color(0xFF388E3C), const Color(0xFF1B5E20)],
                    highlight: callHighlight,
                    onPressed: () {
                      if (_gameMode == GameMode.demo) {
                        _executeDemoUserAction('Call');
                      } else {
                        _executeFreePlayUserAction('Call');
                      }
                    },
                  ),
                const SizedBox(width: 8),
                _buildActionButton(
                  label: 'Raise',
                  subtitle: _gameMode == GameMode.demo ? '₹${_raiseValue.toStringAsFixed(0)}' : null,
                  icon: _gameMode == GameMode.freePlay ? const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 16) : null,
                  gradientColors: [const Color(0xFF7E57C2), const Color(0xFF5E35B1), const Color(0xFF311B92)],
                  highlight: raiseHighlight,
                  onPressed: () {
                    if (_gameMode == GameMode.demo) {
                      _executeDemoUserAction('Raise');
                    } else {
                      if (!_showRaiseSlider) {
                        setState(() {
                          _minRaise = toCall + 2000;
                          _maxRaise = ownPlayer.chips;
                          if (_raiseValue < _minRaise) _raiseValue = _minRaise;
                          _showRaiseSlider = true;
                        });
                      } else {
                        _executeFreePlayUserAction('Raise', _raiseValue);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onPressed,
    String? subtitle,
    Widget? icon,
    bool highlight = false,
  }) {
    return Container(
      width: 90,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? Colors.amberAccent : const Color(0xFFFFD700),
          width: highlight ? 2.5 : 1.5,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: Colors.amberAccent.withOpacity(0.8),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : [
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
                    color: Color(0xFFFFEB3B),
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

  @override
  Widget build(BuildContext context) {
    PlayerState ownPlayer = _players['Mehidi'] ??
        PlayerState(name: 'Mehidi', avatarAsset: 'assets/images/avatar_own.png', chips: 136000);

    bool isOwnTurn = (_activePlayerName == 'Mehidi');

    return Scaffold(
      backgroundColor: const Color(0xFF072013),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background image
          const Image(
            image: AssetImage('assets/images/poker_bg_full.png'),
            fit: BoxFit.cover,
          ),

          // 2. Aspect Ratio Centered Table
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
                      // Table Felt with Purple Filter to match the video
                      Positioned(
                        left: 40,
                        right: 40,
                        top: 25,
                        bottom: 25,
                        child: Image.asset(
                          'assets/images/poker_table.png',
                          fit: BoxFit.fill,
                          color: const Color(0xFF322A5E).withOpacity(0.82),
                          colorBlendMode: BlendMode.color,
                        ),
                      ),

                      // TEEN PATTI GOLD Watermark on Felt
                      Positioned(
                        top: 140,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            'TEEN PATTI GOLD',
                            style: TextStyle(
                              color: const Color(0xFFFFD700).withOpacity(0.09),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ),

                      // Dealer female character at the top center
                      Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          heightFactor: 0.42,
                          child: AnimatedScale(
                            scale: _dealerScale,
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutBack,
                            child: Image.asset(
                              'assets/images/poker_dealer.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      // Tip dealer button
                      Positioned(
                        top: 86,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              _playGameSound('tip_dealer.mp3');
                              _nudgeDealer();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset('assets/images/poker_chip.png', width: 9, height: 9),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Tip',
                                    style: TextStyle(
                                      color: Colors.white,
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

                      // Pot display capsule
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
                                  _formatCurrency(_pot),
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

                      // 5 card outline slots on felt
                      Positioned(
                        top: 146,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildEmptyCardPlaceholder(),
                            const SizedBox(width: 4),
                            _buildEmptyCardPlaceholder(),
                            const SizedBox(width: 4),
                            _buildEmptyCardPlaceholder(),
                            const SizedBox(width: 4),
                            _buildEmptyCardPlaceholder(dotted: true),
                            const SizedBox(width: 4),
                            _buildEmptyCardPlaceholder(dotted: true),
                          ],
                        ),
                      ),

                      // Fly in community cards
                      if (_communityCards.isNotEmpty)
                        Positioned(
                          top: 146,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _communityCards.map((card) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                child: PokerCard(
                                  rank: card.rank,
                                  suit: card.suit,
                                  width: 44,
                                  height: 60,
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      // Player Seats Rendering
                      if (_players['Guest_6187'] != null)
                        _buildSeat(
                          player: _players['Guest_6187']!,
                          x: -0.65,
                          y: 0.28,
                          tableW: tableW,
                          tableH: tableH,
                          showStars: true,
                        ),

                      _buildSeat(
                        player: PlayerState(name: 'Invite', avatarAsset: '', chips: 0),
                        x: -0.55,
                        y: -0.45,
                        tableW: tableW,
                        tableH: tableH,
                        isInvite: true,
                      ),

                      if (_players['MXPLAYER'] != null)
                        _buildSeat(
                          player: _players['MXPLAYER']!,
                          x: 0.55,
                          y: -0.45,
                          tableW: tableW,
                          tableH: tableH,
                          showCrown: true,
                        ),

                      if (_players['SHAHZAIB'] != null)
                        _buildSeat(
                          player: _players['SHAHZAIB']!,
                          x: 0.65,
                          y: 0.28,
                          tableW: tableW,
                          tableH: tableH,
                          showDealerBtn: true,
                        ),

                      // User Main Avatar
                      _buildOwnPlayerSection(ownPlayer, isOwnTurn),

                      // User Hole Cards
                      if (!ownPlayer.isFolded && ownPlayer.cards.isNotEmpty)
                        Positioned(
                          bottom: 60,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: SizedBox(
                              width: 76,
                              height: 64,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    bottom: 0,
                                    child: PokerCard(
                                      rank: ownPlayer.cards[0].rank,
                                      suit: ownPlayer.cards[0].suit,
                                      width: 42,
                                      height: 58,
                                      rotation: -0.12,
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: PokerCard(
                                      rank: ownPlayer.cards[1].rank,
                                      suit: ownPlayer.cards[1].suit,
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

                      // User Action Capsule
                      if (ownPlayer.actionText.isNotEmpty || ownPlayer.bet > 0)
                        Positioned(
                          bottom: 120,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: ownPlayer.isFolded ? const Color(0xFFC62828) : Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: ownPlayer.isFolded ? Colors.redAccent : const Color(0xFF4CAF50),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!ownPlayer.isFolded && ownPlayer.bet > 0) ...[
                                    Image.asset('assets/images/poker_chip.png', width: 12, height: 12),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    ownPlayer.actionText.isNotEmpty
                                        ? (ownPlayer.bet > 0
                                            ? '${ownPlayer.actionText} ₹${ownPlayer.bet.toStringAsFixed(0)}'
                                            : ownPlayer.actionText)
                                        : '₹${ownPlayer.bet.toStringAsFixed(0)}',
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
                        ),

                      // User Control Buttons (Fold, Check/Call, Raise)
                      _buildActionButtons(ownPlayer, isOwnTurn),

                      // Raise Slider Overlay
                      if (_showRaiseSlider && isOwnTurn) _buildRaiseSlider(),

                      // Table Notifications Banner (top banner)
                      if (_bannerText.isNotEmpty)
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
                                _bannerText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Render flying chips overlay
                      ..._flyingChips.map((chip) {
                        return AnimatedPositioned(
                          key: chip.key,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutQuad,
                          left: chip.end.dx - 15,
                          top: chip.end.dy - 15,
                          child: Image.asset(
                            'assets/images/poker_chip.png',
                            width: 30,
                            height: 30,
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),

          // 3. Top HUD Control Bar
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

                // Center HUD Segment: Game Mode Selector Toggle
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _gameMode = GameMode.demo;
                            _initializeGame();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _gameMode == GameMode.demo ? const Color(0xFF2E7D32) : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            'Video Hand',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _gameMode = GameMode.freePlay;
                            _initializeGame();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _gameMode == GameMode.freePlay ? const Color(0xFF2E7D32) : Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Text(
                            'Free Play',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Row(
                  children: [
                    if (_gameMode == GameMode.demo) ...[
                      GestureDetector(
                        onTap: _toggleAutoPlay,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: _isAutoPlaying ? Colors.green : Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isAutoPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
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

          // 4. Side Info Button
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

          // Showdown Overlay for Showdown Round
          if (_roundPhase == 'Showdown' && _gameMode == GameMode.freePlay)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE6C619), Color(0xFFC78018)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2),
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
                        Text(
                          _bannerText.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
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
                            Text(
                              '+₹${_pot.toStringAsFixed(0)}',
                              style: const TextStyle(
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
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
