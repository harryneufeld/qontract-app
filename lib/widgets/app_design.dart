import 'package:flutter/material.dart';

/// Shared rhythm for pages, sections, forms and neighbouring actions.
class AppSpace {
  AppSpace._();
  static const double control = 8;
  static const double group = 16;
  static const double section = 24;
  static const double page = 32;
  static const double radius = 16;
  static const double maxWidth = 1180;
}

class AppPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AppPanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(AppSpace.section)});
  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpace.radius),
            side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant)),
        child: Padding(padding: padding, child: child),
      );
}

class AppPageHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;
  final List<Widget> actions;
  const AppPageHeading(
      {super.key,
      required this.eyebrow,
      required this.title,
      required this.description,
      this.actions = const []});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.4)),
          const SizedBox(height: AppSpace.control),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpace.control),
          Text(description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpace.section),
            Wrap(
                spacing: AppSpace.control,
                runSpacing: AppSpace.control,
                children: actions),
          ],
        ],
      );
}

/// Forms use one rhythm rather than a different gap for every screen.
class AppFormColumn extends StatelessWidget {
  final List<Widget> children;
  const AppFormColumn({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.group),
            children[i],
          ]
        ],
      );
}

/// Readable page width on desktop, with the same safe edges on phones.
class AppPage extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const AppPage({super.key, required this.child, this.maxWidth = 760});
  @override
  Widget build(BuildContext context) => SafeArea(
      child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth), child: child)));
}

class AppPageListView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  const AppPageListView(
      {super.key,
      required this.children,
      this.padding = const EdgeInsets.all(AppSpace.section),
      this.physics});
  @override
  Widget build(BuildContext context) => AppPage(
      child: ListView(padding: padding, physics: physics, children: children));
}

class AppPageScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  const AppPageScrollView(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(AppSpace.section),
      this.physics});
  @override
  Widget build(BuildContext context) => AppPage(
      child: SingleChildScrollView(
          padding: padding, physics: physics, child: child));
}

/// Related fields sit side by side only when both have room to breathe.
class AppFormRow extends StatelessWidget {
  final List<Widget> children;
  const AppFormRow({super.key, required this.children});
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth >= 560 &&
            MediaQuery.textScalerOf(context).scale(14) <= 19) {
          return Row(children: children);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in children)
                if (child is Expanded)
                  child.child
                else if (child is SizedBox &&
                    child.width != null &&
                    child.child == null)
                  const SizedBox(height: AppSpace.group)
                else
                  child,
            ]);
      });
}
