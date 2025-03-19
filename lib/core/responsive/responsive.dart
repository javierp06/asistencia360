import 'package:flutter/material.dart';

class Responsive {
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1100;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 650 && MediaQuery.of(context).size.width < 1100;
  }

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 650;
  }
}