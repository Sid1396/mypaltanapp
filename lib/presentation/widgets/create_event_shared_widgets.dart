import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Gilroy',
        fontWeight: FontWeight.w600,
        fontSize: SizeConfig.sp(13),
        color: Colors.white,
        letterSpacing: SizeConfig.w(0.3),
      ),
    );
  }
}

class FieldTextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  const FieldTextInput({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(8),
        borderRadius: BorderRadius.circular(SizeConfig.r(14)),
        border: Border.all(color: AppColors.primary.withAlpha(35), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: TextStyle(
          fontFamily: 'Gilroy',
          fontWeight: FontWeight.w600,
          fontSize: SizeConfig.sp(15),
          color: Colors.white,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w400,
            fontSize: SizeConfig.sp(14),
            color: Colors.white.withAlpha(80),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: SizeConfig.w(16),
            vertical: SizeConfig.h(15),
          ),
        ),
      ),
    );
  }
}

class FieldPicker extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const FieldPicker({
    super.key,
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(15)),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(8),
          borderRadius: BorderRadius.circular(SizeConfig.r(14)),
          border: Border.all(
            color: filled ? AppColors.primary : AppColors.primary.withAlpha(35),
            width: filled ? 1.8 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: SizeConfig.r(16), color: filled ? AppColors.primary : Colors.white.withAlpha(120)),
            SizedBox(width: SizeConfig.w(8)),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
                  fontSize: SizeConfig.sp(13),
                  color: filled ? Colors.white : Colors.white.withAlpha(100),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PillToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const PillToggle({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20), vertical: SizeConfig.h(10)),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.primary.withAlpha(8),
          borderRadius: BorderRadius.circular(SizeConfig.r(100)),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.primary.withAlpha(35),
            width: selected ? 2 : 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w700,
            fontSize: SizeConfig.sp(13),
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class StepBottomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const StepBottomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(SizeConfig.w(24), 0, SizeConfig.w(24), SizeConfig.h(24)),
      child: SizedBox(
        width: double.infinity,
        height: SizeConfig.h(56),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withAlpha(120),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SizeConfig.r(14))),
          ),
          child: loading
              ? SizedBox(
                  width: SizeConfig.r(22),
                  height: SizeConfig.r(22),
                  child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontWeight: FontWeight.w700,
                    fontSize: SizeConfig.sp(16),
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
