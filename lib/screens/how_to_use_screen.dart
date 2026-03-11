import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// How to use / guide screen
/// Ported from HowToUseView.swift
class HowToUseScreen extends StatefulWidget {
  const HowToUseScreen({super.key});

  @override
  State<HowToUseScreen> createState() => _HowToUseScreenState();
}

// ---JOSEPHINES ADDITION START---
// Changed to StatefulWidget so we can track which steps the user has "read"
// (tapped to expand) — gives it a game-like feel of completing a tutorial
class _HowToUseScreenState extends State<HowToUseScreen>
    with TickerProviderStateMixin {
  // Tracks which steps have been opened/read by the user
  final Set<int> _completedSteps = {};

  // Each step can be expanded to show more detail
  int? _expandedStep;

  // Animation controller for the completion badge
  late AnimationController _badgeController;
  late Animation<double> _badgeScale;
  bool _showCompletedBadge = false;

  // Josephine's soft color palette — matches session_summary_screen.dart
  static const Color _softBlue = Color(0xFF89B4D4);
  static const Color _softPurple = Color(0xFFB39DDB);
  static const Color _softGreen = Color(0xFF81C784);

  // Each step gets its own accent color for a playful, modern look
  static const List<Color> _stepColors = [
    Color(0xFF89B4D4), // soft blue    — connect
    Color(0xFFB39DDB), // soft purple  — settings
    Color(0xFF81C784), // soft green   — session
    Color(0xFF80CBC4), // soft teal    — progress
    Color(0xFFFFCC80), // soft amber   — goals
  ];

  @override
  void initState() {
    super.initState();
    _badgeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _badgeScale = CurvedAnimation(
      parent: _badgeController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _badgeController.dispose();
    super.dispose();
  }

  // When a step is tapped, mark it complete and check if all done
  void _onStepTapped(int index) {
    setState(() {
      _expandedStep = _expandedStep == index ? null : index;
      _completedSteps.add(index);
    });

    // Show celebration badge when all 5 steps are read
    if (_completedSteps.length == 5 && !_showCompletedBadge) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _showCompletedBadge = true);
          _badgeController.forward(from: 0);
          // Auto-hide after 4 seconds
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => _showCompletedBadge = false);
          });
        }
      });
    }
  }
  // ---JOSEPHINES ADDITION END---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ---JOSEPHINES ADDITION START---
      // Transparent appbar so the gradient shows through
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'How to Use Calmwand',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF5C6BC0), // soft indigo
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF5C6BC0),
        iconTheme: const IconThemeData(color: Color(0xFF5C6BC0)),
      ),
      // ---JOSEPHINES ADDITION END---
      body: Stack(
        children: [
          // ---JOSEPHINES ADDITION START---
          // Soft gradient background — matches session screen exactly
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFDCEEFA), // soft sky blue
                  Color(0xFFEDE7F6), // soft lavender
                  Color(0xFFF1F8E9), // soft mint white
                ],
              ),
            ),
          ),

          // ---JOSEPHINES ADDITION END---
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: [
              // ---JOSEPHINES ADDITION START---
              // Welcoming header card with progress tracker
              _buildHeaderCard(),
              const SizedBox(height: 20),
              // ---JOSEPHINES ADDITION END---

              // ---JOSEPHINES ADDITION START---
              // Physical setup card — from the official CalmWand leaflet
              _buildPhysicalSetupCard(),
              const SizedBox(height: 16),
              // ---JOSEPHINES ADDITION END---

              // Steps — now tappable with expand/collapse and completion tracking
              _buildStep(
                index: 0,
                icon: Icons.bluetooth,
                title: '1. Connect Your Device',
                shortDesc: 'Pair with your Calmwand via Bluetooth',
                fullDesc:
                    'First, turn your Calmwand on using the switch on the side. '
                    'Then hold it so the sensor (small dot) faces your palm, and close your hand comfortably around it.\n\n'
                    'Go to Settings and tap "Connect" to pair via Bluetooth. '
                    'On Chrome/web, a popup will appear to select your device. '
                    'Make sure your wand is on and nearby.',
              ),
              const SizedBox(height: 16),
              _buildStep(
                index: 1,
                icon: Icons.tune,
                title: '2. Adjust Settings',
                shortDesc: 'Customize brightness, breathing times & vibration',
                fullDesc:
                    'In the Settings tab, customize brightness, inhale/exhale times, and motor intensity to your preference. '
                    'Start with the defaults and tweak over time — everyone\'s comfort zone is different!',
              ),
              const SizedBox(height: 16),
              _buildStep(
                index: 2,
                icon: Icons.spa,
                title: '3. Start a Session',
                shortDesc:
                    'Breathe with the wand — it tells you when to inhale and exhale',
                fullDesc:
                    'Tap "Start Session" on the Session tab. '
                    'Hold your Calmwand and follow the breathing rhythm — inhale as the circle grows, exhale as it shrinks. 🌿\n\n'
                    '🌈 Color circle: changes color as your hand warms up — grey/purple (cool) → blue → green → white (peak calm). '
                    'The smoother your breathing, the warmer and calmer your hand becomes.\n\n'
                    '✨ Color slider below the circle: a glowing white dot sits on a color spectrum — '
                    'left = least calm, right = most calm. '
                    'As you relax and your hand warms up, the dot gently drifts to the right. '
                    'Try to guide it as far right as you can!',
              ),
              const SizedBox(height: 16),
              _buildStep(
                index: 3,
                icon: Icons.show_chart,
                title: '4. Track Your Progress',
                shortDesc: 'See your scores and temperature over time',
                fullDesc:
                    'After each session, view your score, temperature data, and history. '
                    'Higher scores mean you stayed in the calm zone longer. '
                    'Export sessions as CSV for deeper analysis.',
              ),
              const SizedBox(height: 16),
              _buildStep(
                index: 4,
                icon: Icons.emoji_events,
                title: '5. Set Goals',
                shortDesc: 'Build a consistent practice',
                fullDesc:
                    'Set weekly session goals in the History tab to stay on track. '
                    'Even 5 minutes a day can make a real difference over time. '
                    'You\'ve got this! ⭐',
              ),
              const SizedBox(height: 28),

              // ---JOSEPHINES ADDITION START---
              // Pro tips redesigned as individual cute pill cards instead of a bullet list
              _buildProTipsSection(),
              // ---JOSEPHINES ADDITION END---
            ],
          ),

          // ---JOSEPHINES ADDITION START---
          // "You're ready!" badge that pops up when all steps are read
          if (_showCompletedBadge)
            Center(
              child: ScaleTransition(
                scale: _badgeScale,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 36,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB39DDB), Color(0xFF89B4D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _softPurple.withValues(alpha: 0.5),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🎉', style: TextStyle(fontSize: 44)),
                      SizedBox(height: 10),
                      Text(
                        "You're ready!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Guide complete ✓',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // ---JOSEPHINES ADDITION END---
        ],
      ),
    );
  }

  // ---JOSEPHINES ADDITION START---
  // Header card showing progress through the guide steps
  Widget _buildHeaderCard() {
    final completed = _completedSteps.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _softPurple.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🌿', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to Calmwand',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5C6BC0),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  completed == 5
                      ? 'Guide complete! 🎉'
                      : 'Tap each step to learn more',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 10),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completed / 5,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFB39DDB),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completed / 5 steps read',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Individual step card — tappable, expands to show full description
  // Shows a soft checkmark when completed
  Widget _buildStep({
    required int index,
    required IconData icon,
    required String title,
    required String shortDesc,
    required String fullDesc,
  }) {
    final isCompleted = _completedSteps.contains(index);
    final isExpanded = _expandedStep == index;
    final color = _stepColors[index];

    return GestureDetector(
      onTap: () => _onStepTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isExpanded
              ? color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isExpanded
                ? color.withValues(alpha: 0.6)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Colored icon bubble
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 26, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? color : const Color(0xFF37474F),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        shortDesc,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Checkmark if completed, chevron if not
                isCompleted
                    ? Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, size: 16, color: color),
                      )
                    : Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey.shade400,
                      ),
              ],
            ),
            // Expanded detail text
            if (isExpanded) ...[
              const SizedBox(height: 14),
              Divider(color: color.withValues(alpha: 0.3), height: 1),
              const SizedBox(height: 12),
              Text(
                fullDesc,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF455A64),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---JOSEPHINES ADDITION START---
  // Physical setup card — based on the official CalmWand instruction leaflet
  Widget _buildPhysicalSetupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF81C784).withValues(alpha: 0.15),
            const Color(0xFF89B4D4).withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF81C784).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text('🖐️', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              const Text(
                'How to Hold Your Wand',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF37474F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Three setup steps as a row
          Row(
            children: [
              _buildSetupStep(
                '1',
                'Turn it on',
                Icons.power_settings_new_rounded,
                const Color(0xFF81C784),
              ),
              const SizedBox(width: 8),
              _buildSetupStep(
                '2',
                'Sensor faces palm',
                Icons.back_hand_outlined,
                const Color(0xFF89B4D4),
              ),
              const SizedBox(width: 8),
              _buildSetupStep(
                '3',
                'Close hand gently',
                Icons.pan_tool_rounded,
                const Color(0xFFB39DDB),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Light cue explanation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEB3B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Center light ON → breathe IN',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF37474F),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Center light OFF → breathe OUT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF37474F),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Color spectrum label
          Row(
            children: [
              const Text(
                'least calm',
                style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 10,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF9E9E9E),
                          Color(0xFF7B1FA2),
                          Color(0xFFF44336),
                          Color(0xFFFF9800),
                          Color(0xFFFFEB3B),
                          Color(0xFF4CAF50),
                          Color(0xFF00BCD4),
                          Color(0xFF2196F3),
                          Color(0xFF9C27B0),
                          Color(0xFFFFFFFF), // white — peak calm
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'most calm',
                style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '✨ Good sign: colors changing clockwise + vibration means you\'re heading in the right direction!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Small numbered setup step widget
  Widget _buildSetupStep(
    String number,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ---JOSEPHINES ADDITION END---

  // Pro tips redesigned as individual soft pill cards
  Widget _buildProTipsSection() {
    final tips = [
      ('🧘', 'Find a quiet, comfortable space'),
      ('⏱️', 'Two 10-min sessions a day recommended'),
      ('💨', 'Light ON = inhale. Light OFF = exhale.'),
      ('🖐️', 'Sensor faces palm, close hand gently'),
      (
        '🌡️',
        'Warm Hands: "my hands are heavy and warm, my heartbeat is calm"',
      ),
      ('🎵', 'Try listening to calming music'),
      ('💭', 'Visualise a warm, safe, peaceful place'),
      (
        '✨',
        'Color slider: a glowing dot drifts right as you calm down — try to guide it all the way to the white zone!',
      ),
      ('⚪', 'White zone = peak calm — that\'s the goal!'),
      ('🏆', 'With practice, you\'ll feel calm even without the wand!'),
      ('📅', 'Regular use leads to better sleep and a calmer everyday life'),
    ];

    // ---JOSEPHINES ADDITION START---
    // 2-column grid — cuts the height roughly in half vs the old stacked list
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCC80).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lightbulb_outline,
                color: Color(0xFFFF8F00),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Pro Tips',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5C6BC0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // 2-column Wrap grid
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: tips.map((tip) {
            return SizedBox(
              // Each tile is just under half the screen width
              width: (MediaQuery.of(context).size.width - 20 * 2 - 10) / 2,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _softBlue.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tip.$1, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 6),
                    Text(
                      tip.$2,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF455A64),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
    // ---JOSEPHINES ADDITION END---
  }

  // ---JOSEPHINES ADDITION END---
}
