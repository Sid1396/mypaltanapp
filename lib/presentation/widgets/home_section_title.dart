import 'package:flutter/material.dart';
import '../../utils/helpers/size_config.dart';

class HomeSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const HomeSectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(20)),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(height: 1, color: Colors.white.withAlpha(30)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: SizeConfig.w(14)),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Gilroy',
                      fontWeight: FontWeight.w700,
                      fontSize: SizeConfig.sp(13),
                      letterSpacing: SizeConfig.w(1.2),
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                ),
                if (trailing == null)
                  Expanded(
                    child: Container(height: 1, color: Colors.white.withAlpha(30)),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
