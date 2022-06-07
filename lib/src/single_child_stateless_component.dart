import 'package:jaspr/jaspr.dart';

/// A [Component] that takes a single descendant.
///
/// See also:
/// - [SingleChildStatelessComponent]
abstract class SingleChildComponent implements Component {
  @override
  _SingleChildComponentElementMixin createElement();
}

mixin _SingleChildComponentElementMixin on Element {
  _NestedHookElement? _parent;

  @override
  void mount(Element? parent) {
    if (parent is _NestedHookElement?) {
      _parent = parent;
    }
    super.mount(parent);
  }

  @override
  void activate() {
    super.activate();
    visitAncestorElements((parent) {
      if (parent is _NestedHookElement) {
        _parent = parent;
      }
      return false;
    });
  }
}

class _NestedHook extends StatelessComponent {
  _NestedHook({
    this.injectedChild,
    required this.wrappedWidget,
    required this.owner,
  });

  final SingleChildComponent wrappedWidget;
  final Component? injectedChild;
  final _NestedElement owner;

  @override
  _NestedHookElement createElement() => _NestedHookElement(this);

  @override
  Iterable<Component> build(BuildContext context) => throw StateError('handled internally');
}

/// A widget that simplify the writing of deeply nested widget trees.
///
/// It relies on the new kind of widget [SingleChildComponent], which has two
/// concrete implementations:
/// - [SingleChildStatelessComponent]
///
/// They are both respectively a [SingleChildComponent] variant of [StatelessComponent]
/// and [StatefulComponent].
///
/// The difference between a widget and its single-child variant is that they have
/// a custom `build` method that takes an extra parameter.
///
/// As such, a `StatelessWidget` would be:
///
/// ```dart
/// class MyWidget extends StatelessWidget {
///   MyWidget({Key key, this.child}): super(key: key);
///
///   final Widget child;
///
///   @override
///   Widget build(BuildContext context) {
///     return SomethingWidget(child: child);
///   }
/// }
/// ```
///
/// Whereas a [SingleChildStatelessComponent] would be:
///
/// ```dart
/// class MyWidget extends SingleChildStatelessWidget {
///   MyWidget({Key key, Widget child}): super(key: key, child: child);
///
///   @override
///   Widget buildWithChild(BuildContext context, Widget child) {
///     return SomethingWidget(child: child);
///   }
/// }
/// ```
///
/// This allows our new `MyWidget` to be used both with:
///
/// ```dart
/// MyWidget(
///   child: AnotherWidget(),
/// )
/// ```
///
/// and to be placed inside `children` of [Nested] like so:
///
/// ```dart
/// Nested(
///   children: [
///     MyWidget(),
///     ...
///   ],
///   child: AnotherWidget(),
/// )
/// ```
class Nested extends StatelessComponent implements SingleChildComponent {
  /// Allows configuring key, children and child
  Nested({
    Key? key,
    required List<SingleChildComponent> children,
    Component? child,
  })  : assert(children.isNotEmpty),
        _children = children,
        _child = child,
        super(key: key);

  final List<SingleChildComponent> _children;
  final Component? _child;

  @override
  Iterable<Component> build(BuildContext context) {
    throw StateError('implemented internally');
  }

  @override
  _NestedElement createElement() => _NestedElement(this);
}

class _NestedElement extends StatelessElement with _SingleChildComponentElementMixin {
  _NestedElement(Nested widget) : super(widget);

  @override
  Nested get component => super.component as Nested;

  final nodes = <_NestedHookElement>{};

  @override
  Iterable<Component> build() sync* {
    _NestedHook? nestedHook;
    var nextNode = _parent?.injectedChild ?? component._child;

    for (final child in component._children.reversed) {
      nextNode = nestedHook = _NestedHook(
        owner: this,
        wrappedWidget: child,
        injectedChild: nextNode,
      );
    }

    if (nestedHook != null) {
      // We manually update _NestedHookElement instead of letter widgets do their thing
      // because an item N may be constant but N+1 not. So, if we used widgets
      // then N+1 wouldn't rebuild because N didn't change
      for (final node in nodes) {
        node
          ..wrappedChild = nestedHook!.wrappedWidget
          ..injectedChild = nestedHook.injectedChild;

        final next = nestedHook.injectedChild;
        if (next is _NestedHook) {
          nestedHook = next;
        } else {
          break;
        }
      }
    }

    yield nextNode!;
  }
}

class _NestedHookElement extends StatelessElement {
  _NestedHookElement(_NestedHook widget) : super(widget);

  @override
  _NestedHook get component => super.component as _NestedHook;

  Component? _injectedChild;
  Component? get injectedChild => _injectedChild;
  set injectedChild(Component? value) {
    final previous = _injectedChild;
    if (value is _NestedHook &&
        previous is _NestedHook &&
        Component.canUpdate(value.wrappedWidget, previous.wrappedWidget)) {
      // no need to rebuild the wrapped widget just for a _NestedHook.
      // The widget doesn't matter here, only its Element.
      return;
    }
    if (previous != value) {
      _injectedChild = value;
      visitChildren((e) => e.markNeedsBuild());
    }
  }

  SingleChildComponent? _wrappedChild;
  SingleChildComponent? get wrappedChild => _wrappedChild;
  set wrappedChild(SingleChildComponent? value) {
    if (_wrappedChild != value) {
      _wrappedChild = value;
      markNeedsBuild();
    }
  }

  @override
  void mount(Element? parent) {
    component.owner.nodes.add(this);
    _wrappedChild = component.wrappedWidget;
    _injectedChild = component.injectedChild;
    super.mount(parent);
  }

  @override
  void unmount() {
    component.owner.nodes.remove(this);
    super.unmount();
  }

  @override
  Iterable<Component> build() sync* {
    yield wrappedChild!;
  }
}

/// A [StatelessComponent] that implements [SingleChildComponent] and is therefore
/// compatible with [Nested].
///
/// Its [build] method must **not** be overriden. Instead use [buildWithChild].
abstract class SingleChildStatelessComponent extends StatelessComponent implements SingleChildComponent {
  /// Creates a widget that has exactly one child widget.
  const SingleChildStatelessComponent({Key? key, Component? child})
      : _child = child,
        super(key: key);

  final Component? _child;

  /// A [build] method that receives an extra `child` parameter.
  ///
  /// This method may be called with a `child` different from the parameter
  /// passed to the constructor of [SingleChildStatelessComponent].
  /// It may also be called again with a different `child`, without this widget
  /// being recreated.
  Iterable<Component> buildWithChild(BuildContext context, Component? child);

  @override
  Iterable<Component> build(BuildContext context) => buildWithChild(context, _child);

  @override
  SingleChildStatelessElement createElement() {
    return SingleChildStatelessElement(this);
  }
}

/// An [Element] that uses a [SingleChildStatelessComponent] as its configuration.
class SingleChildStatelessElement extends StatelessElement with _SingleChildComponentElementMixin {
  /// Creates an element that uses the given widget as its configuration.
  SingleChildStatelessElement(SingleChildStatelessComponent widget) : super(widget);

  @override
  Iterable<Component> build() {
    if (_parent != null) {
      return component.buildWithChild(this, _parent!.injectedChild);
    }
    return super.build();
  }

  @override
  SingleChildStatelessComponent get component => super.component as SingleChildStatelessComponent;
}
