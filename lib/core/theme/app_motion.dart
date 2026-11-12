import 'package:flutter/material.dart';

/// Motion rules for the whole app. Movement should explain where something
/// came from or went; it is never decoration. Everything collapses to an
/// instant change when the system "remove animations" setting is on.
abstract final class AppMotion {
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration long = Duration(milliseconds: 350);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration] unless the user asked the system to reduce motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;

  /// Switching between top-level tabs: the old page fades out, the new one
  /// fades and scales in slightly. No direction, because tabs are peers.
  static Widget fadeThrough(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduced(context)) return child;
    final incoming = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.3, 1.0, curve: enter),
    );
    return FadeTransition(
      opacity: incoming,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1.0).animate(incoming),
        child: child,
      ),
    );
  }

  /// Going deeper (a person, a form): slide in from the side so "back" has an
  /// obvious direction.
  static Widget sharedAxisX(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduced(context)) return child;
    final inCurve = CurvedAnimation(parent: animation, curve: enter, reverseCurve: exit);
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: enter, reverseCurve: exit);
    return SlideTransition(
      position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(inCurve),
      child: FadeTransition(
        opacity: inCurve,
        child: SlideTransition(
          position: Tween(begin: Offset.zero, end: const Offset(-0.04, 0)).animate(outCurve),
          child: child,
        ),
      ),
    );
  }
}

/// Applies [AppMotion.sharedAxisX] to every MaterialPageRoute.
class SharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const SharedAxisPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.medium;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      AppMotion.sharedAxisX(context, animation, secondaryAnimation, child);
}
