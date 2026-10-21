import 'package:corner_toast/corner_toast.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

/// Shows every toast kind, an action toast and a sticky toast, with the
/// corner switchable at runtime.
class ExampleApp extends StatefulWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final _toasts = ToastController();
  var _position = ToastPosition.bottomRight;

  @override
  void dispose() {
    _toasts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'corner_toast example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      // One host above every route, so any page can show toasts.
      builder: (context, child) => ToastHost(
        controller: _toasts,
        position: _position,
        child: child!,
      ),
      home: _HomePage(
        position: _position,
        onPosition: (position) => setState(() => _position = position),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.position, required this.onPosition});

  final ToastPosition position;
  final ValueChanged<ToastPosition> onPosition;

  @override
  Widget build(BuildContext context) {
    final toasts = ToastHost.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('corner_toast')),
      body: Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            FilledButton(
              onPressed: () => toasts.success('Saved'),
              child: const Text('Success'),
            ),
            FilledButton.tonal(
              onPressed: () => toasts.info('Sync finished'),
              child: const Text('Info'),
            ),
            FilledButton.tonal(
              onPressed: () => toasts.warning('Disk almost full'),
              child: const Text('Warning'),
            ),
            FilledButton.tonal(
              onPressed: () => toasts.error('Could not connect'),
              child: const Text('Error'),
            ),
            OutlinedButton(
              onPressed: () => toasts.info(
                'File deleted',
                actionLabel: 'Undo',
                onAction: () => toasts.success('Restored'),
              ),
              child: const Text('With action'),
            ),
            OutlinedButton(
              onPressed: () =>
                  toasts.warning('Stays until closed', duration: Duration.zero),
              child: const Text('Sticky'),
            ),
            DropdownMenu<ToastPosition>(
              initialSelection: position,
              label: const Text('Position'),
              onSelected: (value) {
                if (value != null) onPosition(value);
              },
              dropdownMenuEntries: [
                for (final value in ToastPosition.values)
                  DropdownMenuEntry(value: value, label: value.name),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
