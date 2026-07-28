import 'package:flutter/material.dart';

class PlayLayout extends StatelessWidget {
  const PlayLayout({
    super.key,
    required this.left,
    required this.center,
    required this.right,
    this.leftWidth = 340,
    this.centerWidth,
    this.rightWidth = 300,
    this.gap = 12,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget left;
  final Widget center;
  final Widget right;

  final double leftWidth;
  final double? centerWidth;
  final double rightWidth;
  final double gap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerBox = centerWidth == null
            ? center
            : SizedBox(width: centerWidth, child: center);

        final content = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: leftWidth, child: left),
            SizedBox(width: gap),
            centerBox,
            SizedBox(width: gap),
            SizedBox(width: rightWidth, child: right),
          ],
        );

        final knownCenterWidth = centerWidth;
        final knownTotalWidth = knownCenterWidth == null
            ? null
            : padding.horizontal +
                leftWidth +
                knownCenterWidth +
                rightWidth +
                gap * 2;

        final canFit = constraints.maxWidth.isFinite &&
            knownTotalWidth != null &&
            knownTotalWidth <= constraints.maxWidth + 0.5;

        final paddedContent = Padding(
          padding: padding,
          child: content,
        );

        if (canFit) {
          return Align(
            alignment: Alignment.topCenter,
            child: paddedContent,
          );
        }

        // Если пользователь сам увеличил масштаб выше 100%, оставляем
        // горизонтальную прокрутку. На обычном масштабе main.dart заранее
        // уменьшает доску так, чтобы эта прокрутка не требовалась.
        return Scrollbar(
          thumbVisibility: false,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: paddedContent,
          ),
        );
      },
    );
  }
}
