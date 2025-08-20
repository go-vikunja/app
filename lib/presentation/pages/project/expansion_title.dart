import 'package:flutter/material.dart';

class VikunjaExpansionTile extends StatefulWidget {
  final Widget title;
  final List<Widget> children;
  final GestureTapCallback? onTitleTap;

  VikunjaExpansionTile({
    required this.title,
    required this.children,
    this.onTitleTap,
  });

  @override
  State<VikunjaExpansionTile> createState() => _VikunjaExpansionTileState();
}

class _VikunjaExpansionTileState extends State<VikunjaExpansionTile> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          minLeadingWidth: 0,
          horizontalTitleGap: 0,
          contentPadding: EdgeInsets.only(left: 6.0, right: 8.0),
          title: InkWell(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: widget.title,
            ),
            onTap: widget.onTitleTap,
          ),
          leading: IconButton(
            onPressed: () {
              setState(() {
                expanded = !expanded;
              });
            },
            icon: expanded
                ? Icon(Icons.keyboard_arrow_down)
                : Icon(Icons.keyboard_arrow_right),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Column(children: widget.children),
          ),
      ],
    );
  }
}
