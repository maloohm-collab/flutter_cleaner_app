import 'package:flutter/material.dart';
import '../utils/colors.dart';

class AnimatedButton extends StatefulWidget {
  final String title;
  final IconData? icon;
  final VoidCallback? onPressed;

  const AnimatedButton({
    super.key,
    required this.title,
    this.icon,
    this.onPressed,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        height: 58,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(_pressed ? 0.20 : 0.45),
              blurRadius: _pressed ? 10 : 22,
              spreadRadius: _pressed ? 0 : 2,
            ),
          ],
        ),
        transform: Matrix4.identity()
          ..scale(_pressed ? 0.97 : 1.0),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
              ],
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
