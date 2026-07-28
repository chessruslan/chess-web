import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class NoBounceScrollBehavior extends MaterialScrollBehavior {
  const NoBounceScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
