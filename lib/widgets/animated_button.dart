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
    // التحقق مما إذا كان الزر مفعلاً
    final bool isEnabled = widget.onPressed != null;

    return GestureDetector(
      // لا يتم تفعيل تأثيرات الضغط إلا إذا كان الزر مفعلاً
      onTapDown: isEnabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: Opacity(
        // تخفيف الشفافية إلى 50% إذا كان الزر معطلاً لإعطاء مظهر الـ Disabled
        opacity: isEnabled ? 1.0 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: 58,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                // تقليل توهج الظل بشكل كبير إذا كان الزر معطلاً
                color: AppColors.primary.withOpacity(
                  isEnabled ? (_pressed ? 0.20 : 0.45) : 0.10,
                ),
                blurRadius: _pressed ? 10 : 22,
                spreadRadius: _pressed ? 0 : 2,
              ),
            ],
          ),
          transform: Matrix4.identity()
            ..scale((isEnabled && _pressed) ? 0.97 : 1.0), // الحركة تعمل فقط إذا كان مفعلاً
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: Colors.white, size: 22),
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
      ),
    );
  }
}
