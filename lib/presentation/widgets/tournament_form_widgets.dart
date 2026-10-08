import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../config/app_colors.dart';
import '../../utils/helpers/size_config.dart';
import '../controllers/create_tournament_controller.dart';

TextStyle tfStyle(double size, {FontWeight weight = FontWeight.w400, Color color = Colors.white, double? height}) =>
    TextStyle(fontFamily: 'Gilroy', fontWeight: weight, fontSize: SizeConfig.sp(size), color: color, height: height);

/// Vertical gap helpers so step layouts read cleanly.
Widget gapH(double h) => SizedBox(height: SizeConfig.h(h));

/// Label + optional hint above a field.
class FormLabel extends StatelessWidget {
  final String text;
  final String? hint;
  final bool optional;
  const FormLabel(this.text, {super.key, this.hint, this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: SizeConfig.h(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: text, style: tfStyle(13, weight: FontWeight.w700)),
            if (optional) TextSpan(text: '  Optional', style: tfStyle(12, color: Colors.white.withAlpha(110))),
          ])),
          if (hint != null) ...[
            SizedBox(height: SizeConfig.h(3)),
            Text(hint!, style: tfStyle(12, color: Colors.white.withAlpha(120), height: 1.35)),
          ],
        ],
      ),
    );
  }
}

/// Single-choice chips that wrap onto new lines.
class ChoiceChips extends StatelessWidget {
  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool allowDeselect;
  const ChoiceChips({super.key, required this.options, required this.selected, required this.onSelected, this.allowDeselect = false});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SizeConfig.w(8),
      runSpacing: SizeConfig.h(8),
      children: [
        for (final (code, label) in options)
          _Chip(
            label: label,
            selected: code == selected,
            onTap: () => onSelected(allowDeselect && code == selected ? '' : code),
          ),
      ],
    );
  }
}

/// Multi-choice chips.
class MultiChips extends StatelessWidget {
  final List<(String, String)> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const MultiChips({super.key, required this.options, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SizeConfig.w(8),
      runSpacing: SizeConfig.h(8),
      children: [
        for (final (code, label) in options)
          _Chip(label: label, selected: selected.contains(code), onTap: () => onToggle(code), check: true),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool check;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap, this.check = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(9)),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.primary.withAlpha(8),
          borderRadius: BorderRadius.circular(SizeConfig.r(100)),
          border: Border.all(color: selected ? AppColors.primary : AppColors.primary.withAlpha(35), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (check && selected) ...[
              Icon(Icons.check_rounded, size: SizeConfig.r(15), color: Colors.white),
              SizedBox(width: SizeConfig.w(4)),
            ],
            Text(label, style: tfStyle(13, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Big selectable card with a title and a description (formats, publish options).
class OptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const OptionCard({super.key, required this.title, required this.subtitle, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(SizeConfig.r(14)),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(25) : AppColors.primary.withAlpha(8),
          borderRadius: BorderRadius.circular(SizeConfig.r(14)),
          border: Border.all(color: selected ? AppColors.primary : AppColors.primary.withAlpha(35), width: selected ? 2 : 1.2),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.primary : Colors.white.withAlpha(160), size: SizeConfig.r(24)),
            SizedBox(width: SizeConfig.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tfStyle(15, weight: FontWeight.w800, color: selected ? AppColors.primary : Colors.white)),
                  SizedBox(height: SizeConfig.h(3)),
                  Text(subtitle, style: tfStyle(12, color: Colors.white.withAlpha(140), height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label on the left, − value + on the right.
class NumberStepper extends StatelessWidget {
  final String label;
  final String? hint;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;
  final String Function(int)? display;
  const NumberStepper({
    super.key,
    required this.label,
    this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.display,
  });

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, bool enabled, int to) => GestureDetector(
          onTap: enabled ? () => onChanged(to) : null,
          child: Container(
            width: SizeConfig.r(36),
            height: SizeConfig.r(36),
            decoration: BoxDecoration(
              color: enabled ? AppColors.primary.withAlpha(30) : Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(SizeConfig.r(10)),
            ),
            child: Icon(icon, size: SizeConfig.r(18), color: enabled ? AppColors.primary : Colors.white.withAlpha(50)),
          ),
        );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: SizeConfig.h(6)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tfStyle(14, weight: FontWeight.w600)),
                if (hint != null) Text(hint!, style: tfStyle(12, color: Colors.white.withAlpha(120))),
              ],
            ),
          ),
          btn(Icons.remove_rounded, value - step >= min, value - step),
          SizedBox(
            width: SizeConfig.w(52),
            child: Text(display?.call(value) ?? '$value', textAlign: TextAlign.center, style: tfStyle(17, weight: FontWeight.w800)),
          ),
          btn(Icons.add_rounded, value + step <= max, value + step),
        ],
      ),
    );
  }
}

/// Label + description with a switch.
class SwitchRow extends StatelessWidget {
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;
  const SwitchRow({super.key, required this.label, this.hint, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: SizeConfig.h(4)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tfStyle(14, weight: FontWeight.w600)),
                if (hint != null) ...[
                  SizedBox(height: SizeConfig.h(2)),
                  Text(hint!, style: tfStyle(12, color: Colors.white.withAlpha(120), height: 1.35)),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// Rounded dark card that groups related fields.
class FormCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const FormCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.symmetric(horizontal: SizeConfig.w(14), vertical: SizeConfig.h(8)),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(SizeConfig.r(14)),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: child,
    );
  }
}

/// Orange-tinted note for important information.
class InfoNote extends StatelessWidget {
  final String text;
  final IconData icon;
  const InfoNote(this.text, {super.key, this.icon = Icons.info_outline_rounded});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SizeConfig.r(12)),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(SizeConfig.r(12)),
        border: Border.all(color: AppColors.primary.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: SizeConfig.r(18), color: AppColors.primary),
          SizedBox(width: SizeConfig.w(10)),
          Expanded(child: Text(text, style: tfStyle(12.5, color: Colors.white.withAlpha(200), height: 1.4))),
        ],
      ),
    );
  }
}

/// Shows a local file if we have one (instant after upload), otherwise the signed URL.
class UploadedImage extends StatelessWidget {
  final UploadedFile file;
  final BoxFit fit;
  const UploadedImage(this.file, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(color: const Color(0xFF222222), child: Icon(Icons.image_rounded, color: Colors.white.withAlpha(60)));
    if (file.localPath != null && File(file.localPath!).existsSync()) {
      return Image.file(File(file.localPath!), fit: fit, errorBuilder: (_, __, ___) => fallback);
    }
    if (file.url != null) return Image.network(file.url!, fit: fit, errorBuilder: (_, __, ___) => fallback);
    return fallback;
  }
}

/// Tap-to-upload image box bound to an [UploadSlot].
class UploadBox extends StatelessWidget {
  final UploadSlot slot;
  final double aspectRatio;
  final String label;
  final String? hint;
  final IconData icon;
  final VoidCallback onPick;
  final VoidCallback? onRemove;
  final double? width;
  const UploadBox({
    super.key,
    required this.slot,
    required this.aspectRatio,
    required this.label,
    required this.onPick,
    this.hint,
    this.icon = Icons.add_photo_alternate_rounded,
    this.onRemove,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final file = slot.file.value;
      final busy = slot.busy.value;
      return SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: GestureDetector(
            onTap: busy ? null : onPick,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(8),
                borderRadius: BorderRadius.circular(SizeConfig.r(14)),
                border: Border.all(color: file != null ? AppColors.primary : AppColors.primary.withAlpha(50), width: file != null ? 1.8 : 1.2),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (file != null)
                    UploadedImage(file)
                  else
                    Padding(
                      padding: EdgeInsets.all(SizeConfig.r(8)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: AppColors.primary, size: SizeConfig.r(26)),
                          SizedBox(height: SizeConfig.h(6)),
                          Text(label, textAlign: TextAlign.center, style: tfStyle(12.5, weight: FontWeight.w700)),
                          if (hint != null)
                            Text(hint!, textAlign: TextAlign.center, style: tfStyle(11, color: Colors.white.withAlpha(110))),
                        ],
                      ),
                    ),
                  if (busy)
                    Container(
                      color: Colors.black.withAlpha(150),
                      child: const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5)),
                    ),
                  if (file != null && !busy)
                    Positioned(
                      top: SizeConfig.r(6),
                      right: SizeConfig.r(6),
                      child: Row(
                        children: [
                          _CornerButton(icon: Icons.edit_rounded, onTap: onPick),
                          if (onRemove != null) ...[SizedBox(width: SizeConfig.w(6)), _CornerButton(icon: Icons.close_rounded, onTap: onRemove!)],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _CornerButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CornerButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: SizeConfig.r(28),
        height: SizeConfig.r(28),
        decoration: BoxDecoration(color: Colors.black.withAlpha(170), shape: BoxShape.circle),
        child: Icon(icon, size: SizeConfig.r(15), color: Colors.white),
      ),
    );
  }
}

/// Bottom sheet frame used by the document and sponsor editors.
class SheetFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const SheetFrame({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.9),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(SizeConfig.r(24))),
      ),
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(SizeConfig.w(20), SizeConfig.h(12), SizeConfig.w(20), SizeConfig.h(20) + mq.padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: SizeConfig.w(40),
                height: 4,
                decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            gapH(16),
            Text(title, style: tfStyle(20, weight: FontWeight.w800)),
            gapH(16),
            ...children,
          ],
        ),
      ),
    );
  }
}
