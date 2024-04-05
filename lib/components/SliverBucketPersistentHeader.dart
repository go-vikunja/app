import 'package:flutter/material.dart';

class SliverBucketPersistentHeader extends StatelessWidget {
  final Widget child;
  final double minExtent;
  final double maxExtent;

  const SliverBucketPersistentHeader({
    Key? key,
    required this.child,
    this.minExtent = 10.0,
    this.maxExtent = 10.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate:
          _SliverBucketPersistentHeaderDelegate(child, minExtent, maxExtent),
    );
  }
}

class _SliverBucketPersistentHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double min;
  final double max;

  _SliverBucketPersistentHeaderDelegate(this.child, this.min, this.max);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => max;

  @override
  double get minExtent => min;

  @override
  bool shouldRebuild(
      covariant _SliverBucketPersistentHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.min != min ||
        oldDelegate.max != max;
  }
}
