import 'dart:async';

/// HomeShell keeps Explore/Map/AR alive in an IndexedStack, so a screen
/// that already fetched its drops once (e.g. ARScreen in initState) has
/// no natural signal to refetch when a new drop is created from a
/// different screen. This is a minimal broadcast bus for that one
/// notification — screens that care subscribe in initState and refetch
/// when it fires.
class DropEvents {
  DropEvents._();
  static final DropEvents instance = DropEvents._();

  final _controller = StreamController<void>.broadcast();

  Stream<void> get onDropCreated => _controller.stream;

  void notifyDropCreated() => _controller.add(null);

  void dispose() => _controller.close();
}
