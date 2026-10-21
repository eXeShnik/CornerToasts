import 'package:corner_toast/corner_toast.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToastController', () {
    test('keeps the newest toasts up to maxVisible', () {
      final controller = ToastController(maxVisible: 3);
      for (var i = 0; i < 5; i++) {
        controller.info('t$i');
      }
      expect(controller.toasts.map((t) => t.message), ['t2', 't3', 't4']);
    });

    test('shorthands set the kind and the default duration', () {
      final controller = ToastController(
        defaultDuration: const Duration(seconds: 2),
      );
      expect(controller.success('a').kind, ToastKind.success);
      expect(controller.info('b').kind, ToastKind.info);
      expect(controller.warning('c').kind, ToastKind.warning);
      final error = controller.error('d');
      expect(error.kind, ToastKind.error);
      expect(error.duration, const Duration(seconds: 2));
      expect(controller.info('e', duration: Duration.zero).sticky, isTrue);
    });

    test('dismiss and clear notify only when something changes', () {
      final controller = ToastController();
      var notified = 0;
      controller.addListener(() => notified++);
      final toast = controller.info('a');
      controller.info('b');
      expect(notified, 2);

      controller.dismiss(toast.id);
      expect(controller.toasts.map((t) => t.message), ['b']);
      controller.dismiss(toast.id);
      expect(notified, 3);

      controller.clear();
      controller.clear();
      expect(controller.toasts, isEmpty);
      expect(notified, 4);
    });

    test('the toast list cannot be changed from outside', () {
      final controller = ToastController()..info('a');
      expect(() => controller.toasts.clear(), throwsUnsupportedError);
    });

    test('an action needs a label', () {
      final controller = ToastController();
      expect(() => controller.info('a', onAction: () {}), throwsAssertionError);
    });
  });

  test('the built-in look follows the brightness and the app scheme', () {
    final light = ThemeData(colorSchemeSeed: Colors.teal);
    final dark = ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.dark,
    );
    expect(
      ToastStyle.fallback(light, ToastKind.info).background,
      light.colorScheme.surfaceContainerHigh,
    );
    for (final kind in [
      ToastKind.success,
      ToastKind.warning,
      ToastKind.error
    ]) {
      final onLight = ToastStyle.fallback(light, kind);
      final onDark = ToastStyle.fallback(dark, kind);
      expect(onDark.background, isNot(onLight.background));
      expect(
        onDark.background.computeLuminance(),
        lessThan(onDark.foreground.computeLuminance()),
      );
      expect(
        onLight.background.computeLuminance(),
        greaterThan(onLight.foreground.computeLuminance()),
      );
    }
  });

  group('ToastHost', () {
    late ToastController controller;

    setUp(() => controller = ToastController());
    tearDown(() => controller.dispose());

    Future<void> pumpHost(
      WidgetTester tester, {
      ToastController? toasts,
      ToastPosition position = ToastPosition.bottomRight,
      ToastTheme theme = const ToastTheme(),
      Size size = const Size(1200, 800),
      TextDirection textDirection = TextDirection.ltr,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => Directionality(
            textDirection: textDirection,
            child: ToastHost(
              controller: toasts ?? controller,
              position: position,
              theme: theme,
              child: child!,
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => ToastHost.of(context).success('From page'),
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('pages reach the controller through ToastHost.of', (
      tester,
    ) async {
      await pumpHost(tester);
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.text('From page'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a toast dismisses itself after its duration', (tester) async {
      await pumpHost(tester);
      controller.success('Saved', duration: const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('a sticky toast stays until closed', (tester) async {
      await pumpHost(tester);
      controller.warning('Stays', duration: Duration.zero);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Stays'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Stays'), findsNothing);
    });

    testWidgets('hovering pauses the countdown', (tester) async {
      await pumpHost(tester);
      controller.info('Hover me', duration: const Duration(seconds: 2));
      await tester.pumpAndSettle();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Hover me')));
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Hover me'), findsOneWidget);

      // Leaving restarts the full countdown.
      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Hover me'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Hover me'), findsNothing);
    });

    testWidgets('the action dismisses the toast and then runs', (
      tester,
    ) async {
      await pumpHost(tester);
      var undone = false;
      controller.info(
        'Deleted',
        actionLabel: 'Undo',
        onAction: () => undone = controller.toasts.isEmpty,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, isTrue, reason: 'dismissed before the callback');
      expect(find.text('Deleted'), findsNothing);
    });

    testWidgets('the newest toast sits closest to the anchored edge', (
      tester,
    ) async {
      double top(String text) => tester.getTopLeft(find.text(text)).dy;

      await pumpHost(tester);
      controller
        ..info('older')
        ..info('newer');
      await tester.pumpAndSettle();
      expect(top('newer'), greaterThan(top('older')));
      expect(tester.getTopRight(find.text('newer')).dx, greaterThan(600));

      controller.clear();
      await pumpHost(tester, position: ToastPosition.topLeft);
      controller
        ..info('older')
        ..info('newer');
      await tester.pumpAndSettle();
      expect(top('newer'), lessThan(top('older')));
      expect(tester.getTopLeft(find.text('newer')).dx, lessThan(600));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('taps outside the cards reach the page', (tester) async {
      await pumpHost(tester);
      controller.info('Overlay is up', duration: Duration.zero);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.text('From page'), findsOneWidget);
      controller.clear();
      await tester.pumpAndSettle();
    });

    testWidgets('a theme overrides one kind and keeps the others', (
      tester,
    ) async {
      await pumpHost(
        tester,
        theme: const ToastTheme(
          styles: {
            ToastKind.success: ToastStyle(
              background: Color(0xFF123456),
              foreground: Color(0xFFFFFFFF),
              icon: Icons.done_all,
            ),
          },
        ),
      );
      controller
        ..success('custom', duration: Duration.zero)
        ..error('builtin', duration: Duration.zero);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.done_all), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      final card = tester.widget<Material>(
        find
            .ancestor(of: find.text('custom'), matching: find.byType(Material))
            .first,
      );
      expect(card.color, const Color(0xFF123456));
      controller.clear();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'a stack taller than the screen scrolls instead of '
        'overflowing', (tester) async {
      await pumpHost(tester, size: const Size(800, 300));
      for (var i = 0; i < 4; i++) {
        controller.info(
          'Toast $i with a message long enough to wrap onto several lines '
          'of the card',
          duration: Duration.zero,
        );
      }
      await tester.pumpAndSettle();

      final newest = tester.getRect(find.textContaining('Toast 3'));
      expect(newest.top, greaterThanOrEqualTo(0));
      expect(newest.bottom, lessThanOrEqualTo(300));
      controller.clear();
      await tester.pumpAndSettle();
    });

    testWidgets('new host settings apply in the same frame', (tester) async {
      await pumpHost(tester);
      controller.info('Moves', duration: Duration.zero);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Moves')).dy, greaterThan(400));

      await pumpHost(tester, position: ToastPosition.topLeft);
      expect(tester.getTopLeft(find.text('Moves')).dy, lessThan(400));
      controller.clear();
      await tester.pumpAndSettle();
    });

    testWidgets('a new controller gets fresh cards', (tester) async {
      await pumpHost(tester);
      controller.info('Sticky', duration: Duration.zero);
      await tester.pumpAndSettle();

      // Both controllers number their first toast 0, and the swap happens
      // with a toast on each side, so a card keyed by id would be reused.
      final other = ToastController()
        ..info('Timed', duration: const Duration(seconds: 2));
      addTearDown(other.dispose);
      await pumpHost(tester, toasts: other);
      await tester.pumpAndSettle();
      expect(find.text('Timed'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Timed'), findsNothing);
      expect(other.toasts, isEmpty);
    });

    testWidgets('card padding follows the text direction', (tester) async {
      await pumpHost(tester, textDirection: TextDirection.rtl);
      controller.info('RTL', duration: Duration.zero);
      await tester.pumpAndSettle();

      final card = tester.getRect(
        find
            .ancestor(of: find.text('RTL'), matching: find.byType(Material))
            .first,
      );
      final icon = tester.getRect(find.byIcon(Icons.notifications_outlined));
      expect(card.right - icon.right, 12);
      controller.clear();
      await tester.pumpAndSettle();
    });

    group('keyboard', () {
      // The label of the focused button: a text button's text, or an icon
      // button's tooltip.
      String? focused() {
        final context = FocusManager.instance.primaryFocus?.context;
        final text = context?.findAncestorWidgetOfExactType<TextButton>();
        if (text != null) return (text.child! as Text).data;
        return context?.findAncestorWidgetOfExactType<IconButton>()?.tooltip;
      }

      // The message of the toast whose card holds focus.
      String? focusedToast() => FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<ToastCard>()
          ?.toast
          .message;

      Future<void> pressShortcut(WidgetTester tester) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pump();
      }

      Future<void> focusPage(WidgetTester tester) async {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focused(), 'Show');
      }

      testWidgets('the shortcut reaches the newest toast and goes back', (
        tester,
      ) async {
        await pumpHost(tester);
        await focusPage(tester);
        controller
          ..info('older', duration: Duration.zero, actionLabel: 'Open')
          ..info('newer', duration: Duration.zero, actionLabel: 'Undo');
        await tester.pumpAndSettle();

        await pressShortcut(tester);
        expect(focused(), 'Undo');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        expect(focused(), 'Close');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        expect(focused(), 'Open');

        await pressShortcut(tester);
        expect(focused(), 'Show');
        controller.clear();
        await tester.pumpAndSettle();
      });

      testWidgets('Escape closes the focused toast and returns focus', (
        tester,
      ) async {
        await pumpHost(tester);
        await focusPage(tester);
        controller.info('Closes', duration: Duration.zero);
        await tester.pumpAndSettle();

        await pressShortcut(tester);
        expect(focused(), 'Close');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Closes'), findsNothing);
        expect(focused(), 'Show');
      });

      testWidgets('focus inside a card holds its countdown', (tester) async {
        await pumpHost(tester);
        await focusPage(tester);
        controller.info('Held', duration: const Duration(seconds: 2));
        await tester.pumpAndSettle();

        await pressShortcut(tester);
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('Held'), findsOneWidget);

        await pressShortcut(tester);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('Held'), findsNothing);
      });

      testWidgets('a null shortcut leaves the key to the app', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyT, alt: true): () =>
                    pressed = true,
              },
              child: ToastHost(
                controller: controller,
                focusShortcut: null,
                child: child!,
              ),
            ),
            home: Scaffold(
              body: TextButton(onPressed: () {}, child: const Text('Show')),
            ),
          ),
        );
        await focusPage(tester);
        controller.info('Ignored', duration: Duration.zero);
        await tester.pumpAndSettle();

        await pressShortcut(tester);
        expect(pressed, isTrue);
        expect(focused(), 'Show');
        controller.clear();
        await tester.pumpAndSettle();
      });

      testWidgets('leaving the toasts skips a page that has closed', (
        tester,
      ) async {
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            builder: (context, child) =>
                ToastHost(controller: controller, child: child!),
            home: Scaffold(
              body: TextButton(onPressed: () {}, child: const Text('Show')),
            ),
          ),
        );
        await focusPage(tester);
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () {}, child: const Text('Second')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focused(), 'Second');
        controller.info('Stays', duration: Duration.zero);
        await tester.pumpAndSettle();

        await pressShortcut(tester);
        expect(focused(), 'Close');
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(focused(), 'Close', reason: 'popping a page keeps focus here');

        await pressShortcut(tester);
        expect(focused(), 'Show');
        controller.clear();
        await tester.pumpAndSettle();
      });

      testWidgets('a host inside a page stays out of its Tab order', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ToastHost(
              controller: controller,
              child: Scaffold(
                body: Column(
                  children: [
                    TextButton(onPressed: () {}, child: const Text('One')),
                    TextButton(onPressed: () {}, child: const Text('Two')),
                  ],
                ),
              ),
            ),
          ),
        );
        controller.info(
          'Toast',
          duration: Duration.zero,
          actionLabel: 'Undo',
          onAction: () {},
        );
        await tester.pumpAndSettle();

        final visited = <String?>[];
        for (var i = 0; i < 4; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          visited.add(focused());
        }
        expect(visited, ['One', 'Two', 'One', 'Two']);

        Future<void> pressArrows() async {
          for (final key in [
            LogicalKeyboardKey.arrowRight,
            LogicalKeyboardKey.arrowDown,
          ]) {
            await tester.sendKeyEvent(key);
            await tester.pump();
            expect(focused(), isIn(['One', 'Two']));
          }
        }

        await pressArrows();
        await pressShortcut(tester);
        expect(focused(), 'Undo');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focused(), 'Close');
        await pressShortcut(tester);
        expect(focused(), isIn(['One', 'Two']));
        await pressArrows();
        controller.clear();
        await tester.pumpAndSettle();
      });

      testWidgets('the action runs once however often it is pressed', (
        tester,
      ) async {
        await pumpHost(tester);
        await focusPage(tester);
        var runs = 0;
        controller.info(
          'Deleted',
          duration: Duration.zero,
          actionLabel: 'Undo',
          onAction: () => runs++,
        );
        await tester.pumpAndSettle();

        await pressShortcut(tester);
        expect(focused(), 'Undo');
        // The closing card keeps focus while it folds away.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.tap(find.text('Undo'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(runs, 1);
        expect(focused(), 'Show');
      });

      // A host inside a page, as apps place it to keep toasts per page.
      // A host inside a page, with focus on the page's button.
      Future<GlobalKey<NavigatorState>> pumpPageHost(
        WidgetTester tester,
      ) async {
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: ToastHost(
              controller: controller,
              child: Scaffold(
                body: TextButton(onPressed: () {}, child: const Text('Page')),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focused(), 'Page');
        return navigator;
      }

      Future<void> confirmOpensDialog(WidgetTester tester) async {
        final navigator = await pumpPageHost(tester);
        controller
          ..info('older', duration: Duration.zero, actionLabel: 'Open')
          ..info(
            'Delete?',
            duration: Duration.zero,
            actionLabel: 'Confirm',
            onAction: () => showDialog<void>(
              context: navigator.currentContext!,
              builder: (context) => const AlertDialog(content: Text('Sure?')),
            ),
          );
        await tester.pumpAndSettle();

        await pressShortcut(tester);
        expect(focused(), 'Confirm');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        final focusContext = FocusManager.instance.primaryFocus!.context!;
        expect(ModalRoute.of(focusContext), isA<DialogRoute<void>>());
        controller.clear();
        await tester.pumpAndSettle();
      }

      testWidgets('an action that opens a dialog leaves focus in it', (
        tester,
      ) async {
        await confirmOpensDialog(tester);
      });

      testWidgets(
          'an action that opens a dialog leaves focus in it without '
          'animations', (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await confirmOpensDialog(tester);
      });

      testWidgets(
          'above the Navigator the shortcut works before anything has '
          'focus', (tester) async {
        await pumpHost(tester);
        controller.info('Reached', duration: Duration.zero);
        await tester.pumpAndSettle();

        await pressShortcut(tester);
        expect(focused(), 'Close');
        controller.clear();
        await tester.pumpAndSettle();
      });

      testWidgets('only the host nearest focus answers', (tester) async {
        final outer = ToastController();
        addTearDown(outer.dispose);
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            builder: (context, child) =>
                ToastHost(controller: outer, child: child!),
            home: ToastHost(
              controller: controller,
              child: Scaffold(
                body: TextButton(onPressed: () {}, child: const Text('Page')),
              ),
            ),
          ),
        );
        outer.info('outer', duration: Duration.zero);
        controller.info('inner', duration: Duration.zero);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focused(), 'Page');

        await pressShortcut(tester);
        expect(focusedToast(), 'inner');
        await pressShortcut(tester);
        expect(focused(), 'Page');

        // Under a dialog, the page's host is out of the focus path; the host
        // above the Navigator, whose toasts float over the dialog, answers.
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (context) => const AlertDialog(content: Text('Dialog')),
        );
        await tester.pumpAndSettle();
        await pressShortcut(tester);
        expect(focusedToast(), 'outer');
        outer.clear();
        controller.clear();
        await tester.pumpAndSettle();
      });

      testWidgets('holding the shortcut toggles once', (tester) async {
        await pumpPageHost(tester);
        controller.info('Held', duration: Duration.zero);
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyT);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyT);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyT);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pump();
        expect(focused(), 'Close');
        controller.clear();
        await tester.pumpAndSettle();
      });

      testWidgets('Tab still moves between toasts after focus comes back', (
        tester,
      ) async {
        final navigator = await pumpPageHost(tester);
        controller.info(
          'Back',
          duration: Duration.zero,
          actionLabel: 'Undo',
          onAction: () {},
        );
        await tester.pumpAndSettle();

        await pressShortcut(tester);
        expect(focused(), 'Undo');
        // A dialog over the page takes focus; closing it hands focus back to
        // the toast through the page's focus history.
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (context) => const AlertDialog(content: Text('Dialog')),
        );
        await tester.pumpAndSettle();
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(focused(), 'Undo');

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(focused(), 'Close');
        controller.clear();
        await tester.pumpAndSettle();
      });

      testWidgets('the shortcut leaves focus alone when there are no toasts', (
        tester,
      ) async {
        await pumpPageHost(tester);
        var changes = 0;
        void count() => changes++;
        FocusManager.instance.addListener(count);
        addTearDown(() => FocusManager.instance.removeListener(count));

        await pressShortcut(tester);
        await tester.pump();
        expect(changes, 0, reason: 'focus must not leave and come back');
        expect(focused(), 'Page');
      });

      testWidgets('a card closed from outside does nothing more', (
        tester,
      ) async {
        await pumpPageHost(tester);
        var runs = 0;
        controller.info(
          'Cleared',
          duration: Duration.zero,
          actionLabel: 'Undo',
          onAction: () => runs++,
        );
        await tester.pumpAndSettle();

        await pressShortcut(tester);
        expect(focused(), 'Undo');
        controller.clear();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(runs, 0);
        expect(focused(), 'Page');
      });

      testWidgets('arrow keys do not move onto a closing card', (tester) async {
        await pumpPageHost(tester);
        controller
          ..info('older', duration: Duration.zero, actionLabel: 'Open')
          ..info('newer', duration: Duration.zero, actionLabel: 'Undo');
        await tester.pumpAndSettle();

        // Escape closes the newer card, which keeps focus while it folds;
        // moving up and then back down must not return to it.
        await pressShortcut(tester);
        expect(focusedToast(), 'newer');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump(const Duration(milliseconds: 20));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(focusedToast(), 'older');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(focusedToast(), isNot('newer'));
        controller.clear();
        await tester.pumpAndSettle();
      });
    });

    testWidgets('a closed toast folds away before it leaves', (tester) async {
      await pumpHost(tester);
      controller
        ..info('older', duration: Duration.zero)
        ..info('newer', duration: Duration.zero);
      await tester.pumpAndSettle();
      final newerTop = tester.getTopLeft(find.text('newer')).dy;
      final olderTop = tester.getTopLeft(find.text('older')).dy;

      controller.dismiss(controller.toasts.last.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(find.text('newer'), findsOneWidget);
      final midway = tester.getTopLeft(find.text('older')).dy;
      expect(midway, greaterThan(olderTop));
      expect(midway, lessThan(newerTop));

      await tester.pumpAndSettle();
      expect(find.text('newer'), findsNothing);
      expect(tester.getTopLeft(find.text('older')).dy, newerTop);
      controller.clear();
      await tester.pumpAndSettle();
    });

    testWidgets('a fold cut short by reduced motion still removes the card', (
      tester,
    ) async {
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpHost(tester);
      controller.info('Cut short', duration: Duration.zero);
      await tester.pumpAndSettle();

      controller.clear();
      await tester.pump(const Duration(milliseconds: 60));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pump();
      await tester.pump();
      expect(find.text('Cut short'), findsNothing);
    });

    testWidgets('reduced motion shows and removes toasts at once', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpHost(tester);

      controller.info('Instant', duration: Duration.zero);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(
        tester
            .widget<Opacity>(
              find
                  .ancestor(
                      of: find.text('Instant'), matching: find.byType(Opacity))
                  .first,
            )
            .opacity,
        1,
      );

      // Hidden at once, and out of the tree a frame later.
      controller.clear();
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('Instant').hitTestable(), findsNothing);
      await tester.pump();
      expect(find.text('Instant'), findsNothing);
    });

    testWidgets('with a screen reader on, a toast with an action waits', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await pumpHost(tester);

      controller
        ..info('Plain', duration: const Duration(seconds: 2))
        ..info(
          'Actionable',
          duration: const Duration(seconds: 2),
          actionLabel: 'Undo',
          onAction: () {},
        );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Plain'), findsNothing);
      expect(find.text('Actionable'), findsOneWidget);
      controller.clear();
      await tester.pumpAndSettle();
    });

    testWidgets('toasts are announced as a live region', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpHost(tester);
      controller.info('Announced', duration: Duration.zero);
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.byType(ToastCard)),
        isSemantics(isLiveRegion: true),
      );
      controller.clear();
      await tester.pumpAndSettle();
      semantics.dispose();
    });
  });

  testWidgets('a ToastOverlay in a page Stack is in the page Tab order', (
    tester,
  ) async {
    final controller = ToastController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const SizedBox.expand(),
              Positioned.fill(child: ToastOverlay(controller: controller)),
            ],
          ),
        ),
      ),
    );
    controller.info('In page', duration: Duration.zero);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final context = FocusManager.instance.primaryFocus?.context;
    expect(context?.findAncestorWidgetOfExactType<ToastCard>(), isNotNull);
    controller.clear();
    await tester.pumpAndSettle();
  });

  testWidgets('pages can show toasts as they open and clear them as they close',
      (
    tester,
  ) async {
    final controller = ToastController();
    addTearDown(controller.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) =>
            ToastHost(controller: controller, child: child!),
        home: const Scaffold(),
      ),
    );

    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => _ToastsWithPage(controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome'), findsOneWidget);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Welcome'), findsNothing);
  });

  testWidgets(
    'taps between cards reach the page',
    variant: TargetPlatformVariant.all(),
    (tester) async {
      final controller = ToastController();
      addTearDown(controller.dispose);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              ToastHost(controller: controller, child: child!),
          home: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand(),
          ),
        ),
      );
      controller
        ..info('older', duration: Duration.zero)
        ..info('newer', duration: Duration.zero);
      await tester.pumpAndSettle();

      Rect card(String text) => tester.getRect(
            find
                .ancestor(of: find.text(text), matching: find.byType(Material))
                .first,
          );
      final older = card('older');
      final newer = card('newer');
      await tester
          .tapAt(Offset(older.center.dx, (older.bottom + newer.top) / 2));
      expect(taps, 1);
      controller.clear();
      await tester.pumpAndSettle();
    },
  );
}

// Shows a toast as it opens and clears the toasts as it closes.
class _ToastsWithPage extends StatefulWidget {
  const _ToastsWithPage(this.controller);

  final ToastController controller;

  @override
  State<_ToastsWithPage> createState() => _ToastsWithPageState();
}

class _ToastsWithPageState extends State<_ToastsWithPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.info('Welcome', duration: Duration.zero);
  }

  @override
  void dispose() {
    widget.controller.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}
