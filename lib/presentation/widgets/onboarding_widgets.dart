import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';

/// Big heading + supporting line used at the top of every onboarding step.
class StepIntro extends StatelessWidget {
  final String title;
  final String subtitle;
  const StepIntro({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w900,
            fontSize: SizeConfig.sp(30),
            color: Colors.white,
            height: 1.15,
          ),
        ),
        SizedBox(height: SizeConfig.h(8)),
        Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w400,
            fontSize: SizeConfig.sp(15),
            color: Colors.white.withAlpha(140),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Selectable row card with a leading icon and a radio tick.
class ChoiceCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const ChoiceCard({super.key, required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(12)),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(25) : AppColors.primary.withAlpha(8),
          borderRadius: BorderRadius.circular(SizeConfig.r(14)),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.primary.withAlpha(35),
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.primary : Colors.white.withAlpha(160), size: SizeConfig.r(22)),
            SizedBox(width: SizeConfig.w(12)),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w700,
                  fontSize: SizeConfig.sp(15),
                  color: selected ? AppColors.primary : Colors.white,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: SizeConfig.r(22),
              height: SizeConfig.r(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(color: selected ? AppColors.primary : Colors.white.withAlpha(60), width: 2),
              ),
              child: selected ? Icon(Icons.check_rounded, color: Colors.white, size: SizeConfig.r(14)) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Back-of-jersey preview showing the player's jersey name and number.
class JerseyPreview extends StatelessWidget {
  final String name;
  final String number;
  final double width;
  const JerseyPreview({super.key, required this.name, required this.number, required this.width});

  @override
  Widget build(BuildContext context) {
    final shownName = name.trim().isEmpty ? 'YOUR NAME' : name.trim().toUpperCase();
    final shownNumber = number.trim().isEmpty ? '00' : number.trim();
    return SizedBox(
      width: width,
      height: width * 0.95,
      child: CustomPaint(
        painter: _JerseyPainter(),
        child: Padding(
          padding: EdgeInsets.only(top: width * 0.2),
          child: Column(
            children: [
              Text(
                shownName,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w900,
                  fontSize: width * 0.1,
                  letterSpacing: width * 0.01,
                  color: name.trim().isEmpty ? Colors.white.withAlpha(110) : Colors.white,
                ),
              ),
              Text(
                shownNumber,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w900,
                  fontSize: width * 0.36,
                  height: 1.05,
                  color: number.trim().isEmpty ? Colors.white.withAlpha(110) : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JerseyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = Path()
      ..moveTo(w * 0.32, 0)
      ..quadraticBezierTo(w * 0.5, h * 0.09, w * 0.68, 0)
      ..lineTo(w * 0.86, h * 0.06)
      ..lineTo(w, h * 0.3)
      ..lineTo(w * 0.83, h * 0.4)
      ..lineTo(w * 0.8, h * 0.33)
      ..lineTo(w * 0.8, h)
      ..lineTo(w * 0.2, h)
      ..lineTo(w * 0.2, h * 0.33)
      ..lineTo(w * 0.17, h * 0.4)
      ..lineTo(0, h * 0.3)
      ..lineTo(w * 0.14, h * 0.06)
      ..close();
    final rect = Offset.zero & size;
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF55018), Color(0xFFB8360A)],
        ).createShader(rect),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..color = Colors.black.withAlpha(60),
    );
    // Collar
    final collar = Path()
      ..moveTo(w * 0.32, 0)
      ..quadraticBezierTo(w * 0.5, h * 0.09, w * 0.68, 0);
    canvas.drawPath(
      collar,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025
        ..color = const Color(0xFF121212),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
