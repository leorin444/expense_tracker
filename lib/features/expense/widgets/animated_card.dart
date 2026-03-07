import 'package:flutter/material.dart';

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double elevation;
  final Color? color;
  final BorderRadius? borderRadius;

  const AnimatedCard({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.elevation = 4.0,
    this.color,
    this.borderRadius,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration);

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _shadowAnimation = Tween<double>(
      begin: 0,
      end: widget.elevation,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Start animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Material(
            elevation: _shadowAnimation.value,
            color: widget.color ?? theme.cardColor,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
            child: widget.child,
          ),
        );
      },
    );
  }
}
