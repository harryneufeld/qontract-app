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

/// Search and menu filters share geometry, typography and field decoration.
class AppFilterStyle {
  AppFilterStyle._();
  static const double gap = 12;
  static double height(BuildContext context) =>
      48 +
      (MediaQuery.textScalerOf(context).scale(16) - 16)
              .clamp(0, double.infinity) *
          1.5;
  static InputDecoration decoration(
          {required BuildContext context,
          String? hintText,
          required IconData icon,
          Widget? suffixIcon}) =>
      InputDecoration(
        hintText: hintText,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        prefixIcon: Icon(icon),
        // Force the painted container to fill its allocated height, including
        // when enlarged text makes the shared height taller than the content.
        prefixIconConstraints:
            BoxConstraints.tightFor(width: 48, height: height(context)),
        hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400),
        suffixIcon: suffixIcon,
        constraints: BoxConstraints.tightFor(height: height(context)),
      );
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

/// Supplies the visible position even when the row is inside another widget.
class AppCollectionItem extends InheritedWidget {
  final bool first;
  final bool last;
  const AppCollectionItem(
      {super.key,
      required this.first,
      required this.last,
      required super.child});
  @override
  bool updateShouldNotify(AppCollectionItem oldWidget) =>
      first != oldWidget.first || last != oldWidget.last;
}

/// A compact group with rounding only at its outer edges.
class AppCollection extends StatelessWidget {
  final List<Widget> children;
  const AppCollection({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++)
            AppCollectionItem(
                first: i == 0,
                last: i == children.length - 1,
                child: AppCollectionRow(child: children[i]))
        ],
      );
}

/// A collection reads as one continuous surface, separated by quiet rules.
class AppCollectionRow extends StatelessWidget {
  final Widget child;
  const AppCollectionRow({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final position =
        context.dependOnInheritedWidgetOfExactType<AppCollectionItem>();
    final first = position?.first ?? true;
    final last = position?.last ?? true;
    final radius = BorderRadius.vertical(
        top: first ? const Radius.circular(AppSpace.radius) : Radius.zero,
        bottom: last ? const Radius.circular(AppSpace.radius) : Radius.zero);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
            border: last
                ? null
                : Border(
                    bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant))),
        child: child,
      ),
    );
  }
}

/// Detail groups use the same rounded surface as collection endpoints.
class AppDetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const AppDetailSection(
      {super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(
              color: Theme.of(context).colorScheme.outlineVariant, height: 1),
          const SizedBox(height: AppSpace.section),
          Semantics(
              header: true,
              child:
                  Text(title, style: Theme.of(context).textTheme.titleLarge)),
          const SizedBox(height: AppSpace.group),
          AppCollectionRow(
              child: Padding(
                  padding: const EdgeInsets.all(AppSpace.group),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children))),
        ],
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
  final double maxWidth;
  const AppPageListView(
      {super.key,
      required this.children,
      this.padding = const EdgeInsets.all(AppSpace.section),
      this.physics,
      this.maxWidth = 760});
  @override
  Widget build(BuildContext context) => AppPage(
      maxWidth: maxWidth,
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
