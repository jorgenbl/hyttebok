import 'package:flutter/material.dart';

/// Enkel skelett-ladning: pulsrende plassholdere som ligner en liste med kort.
///
/// Brukes i stedet for et alenestående spinner mens innhold lastes, slik at
/// brukeren ser «skallet» av skjermen som er på vei inn.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 4});

  /// Antall plassholderkort.
  final int count;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      reverseDuration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.35,
      end: 0.75,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _box(double width, double height, double radius, double opacity) {
    final base = Theme.of(context).colorScheme.outlineVariant;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Color.lerp(Colors.transparent, base, opacity) ?? base,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: widget.count,
      separatorBuilder: (_, _) => const SizedBox.shrink(),
      itemBuilder: (context, i) => AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final opacity = _pulse.value;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                children: [
                  _box(40, 40, 8, opacity),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _box(double.infinity, 14, 4, opacity),
                        const SizedBox(height: 8),
                        _box(120, 10, 4, opacity),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
