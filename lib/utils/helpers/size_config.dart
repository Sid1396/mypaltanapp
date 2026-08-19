import 'package:flutter/material.dart';

class SizeConfig {
  SizeConfig._();

  static double _width = 375;
  static double _height = 812;

  static void init(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _width = size.width;
    _height = size.height;
  }

  static double get screenWidth => _width;
  static double get screenHeight => _height;

  /// Scale horizontally — use for widths, horizontal padding/margin
  static double w(double px) => _width / 375.0 * px;

  /// Scale vertically — use for heights, vertical padding/margin
  static double h(double px) => _height / 812.0 * px;

  /// Scale font size based on screen width
  static double sp(double size) => _width / 375.0 * size;

  /// General responsive scale — use for radius, icon size, square dimensions
  static double r(double size) => _width / 375.0 * size;
}
