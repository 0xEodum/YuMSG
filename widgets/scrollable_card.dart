import 'package:flutter/material.dart';

class ScrollableCard extends StatelessWidget {
  final Widget child;

  final EdgeInsetsGeometry padding;

  const ScrollableCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(24.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeHeight = media.size.height - media.padding.vertical - 32;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: safeHeight,
        ),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
