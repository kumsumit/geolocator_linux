import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

/// Defines the main theme color.
final MaterialColor themeMaterialColor = _createMaterialColor(
  const Color.fromRGBO(48, 49, 60, 1),
);

void main() {
  runApp(const GeolocatorExampleApp());
}

/// Example application showing the functionalities of the geolocator plugin.
class GeolocatorExampleApp extends StatelessWidget {
  /// Creates a new GeolocatorExampleApp.
  const GeolocatorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geolocator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: themeMaterialColor),
        useMaterial3: true,
      ),
      home: const GeolocatorWidget(),
    );
  }
}

/// Example [Widget] showing the functionalities of the geolocator plugin
class GeolocatorWidget extends StatefulWidget {
  /// Create a GeolocatorWidget.
  const GeolocatorWidget({super.key});

  @override
  State<GeolocatorWidget> createState() => _GeolocatorWidgetState();
}

class _GeolocatorWidgetState extends State<GeolocatorWidget> {
  static const String _locationServicesDisabledMessage =
      'Location services are disabled.';
  static const String _permissionDeniedMessage = 'Permission denied.';
  static const String _permissionDeniedForeverMessage =
      'Permission denied forever.';
  static const String _permissionGrantedMessage = 'Permission granted.';

  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;
  final List<_PositionItem> _positionItems = <_PositionItem>[];
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  Widget build(BuildContext context) {
    const buttonSpacer = SizedBox(height: 10);

    return Scaffold(
      appBar: AppBar(title: const Text('Geolocator')),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ListView.builder(
        itemCount: _positionItems.length,
        itemBuilder: (context, index) {
          final positionItem = _positionItems[index];

          if (positionItem.type == _PositionItemType.log) {
            return ListTile(
              title: Text(
                positionItem.displayValue,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          } else {
            return Card(
              child: ListTile(
                tileColor: themeMaterialColor,
                title: Text(
                  positionItem.displayValue,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          }
        },
      ),
      floatingActionButton: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _toggleListening,
            tooltip: (_positionStreamSubscription == null)
                ? 'Start position updates'
                : _positionStreamSubscription!.isPaused
                ? 'Resume'
                : 'Pause',
            backgroundColor: _determineButtonColor(),
            child:
                (_positionStreamSubscription == null ||
                    _positionStreamSubscription!.isPaused)
                ? const Icon(Icons.play_arrow)
                : const Icon(Icons.pause),
          ),
          buttonSpacer,
          FloatingActionButton(
            onPressed: _getCurrentPosition,
            child: const Icon(Icons.my_location),
          ),
          buttonSpacer,
          FloatingActionButton(
            onPressed: () => setState(_positionItems.clear),
            tooltip: 'clear',
            child: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentPosition() async {
    final bool hasPermission = await _handlePermission();

    if (!hasPermission) {
      return;
    }

    final Position position = await _geolocatorPlatform.getCurrentPosition();
    _updatePositionList(_PositionItemType.position, position.toString());
  }

  Future<bool> _handlePermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await _geolocatorPlatform.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await _geolocatorPlatform.openLocationSettings();
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      _updatePositionList(
        _PositionItemType.log,
        _locationServicesDisabledMessage,
      );

      return false;
    }

    permission = await _geolocatorPlatform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _geolocatorPlatform.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        _updatePositionList(_PositionItemType.log, _permissionDeniedMessage);

        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      _updatePositionList(
        _PositionItemType.log,
        _permissionDeniedForeverMessage,
      );

      return false;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    _updatePositionList(_PositionItemType.log, _permissionGrantedMessage);
    return true;
  }

  void _updatePositionList(_PositionItemType type, String displayValue) {
    _positionItems.add(_PositionItem(type, displayValue));
    setState(() {});
  }

  bool _isListening() =>
      !(_positionStreamSubscription == null ||
          _positionStreamSubscription!.isPaused);

  Color _determineButtonColor() {
    return _isListening() ? Colors.green : Colors.red;
  }

  void _toggleListening() {
    if (_positionStreamSubscription == null) {
      final positionStream = _geolocatorPlatform.getPositionStream();
      _positionStreamSubscription = positionStream
          .handleError((error) {
            _positionStreamSubscription?.cancel();
            _positionStreamSubscription = null;
          })
          .listen(
            (position) => _updatePositionList(
              _PositionItemType.position,
              position.toString(),
            ),
          );
      _positionStreamSubscription?.pause();
    }

    setState(() {
      if (_positionStreamSubscription == null) {
        return;
      }

      String statusDisplayValue;
      if (_positionStreamSubscription!.isPaused) {
        _positionStreamSubscription!.resume();
        statusDisplayValue = 'resumed';
      } else {
        _positionStreamSubscription!.pause();
        statusDisplayValue = 'paused';
      }

      _updatePositionList(
        _PositionItemType.log,
        'Listening for position updates $statusDisplayValue',
      );
    });
  }

  @override
  void dispose() {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
    }

    super.dispose();
  }
}

enum _PositionItemType { log, position }

class _PositionItem {
  _PositionItem(this.type, this.displayValue);

  final _PositionItemType type;
  final String displayValue;
}

MaterialColor _createMaterialColor(Color color) {
  final strengths = <double>[.05];
  final swatch = <int, Color>{};
  final argb = color.toARGB32();
  final red = (argb >> 16) & 0xff;
  final green = (argb >> 8) & 0xff;
  final blue = argb & 0xff;

  for (var i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }

  for (final strength in strengths) {
    final double delta = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      red + ((delta < 0 ? red : (255 - red)) * delta).round(),
      green + ((delta < 0 ? green : (255 - green)) * delta).round(),
      blue + ((delta < 0 ? blue : (255 - blue)) * delta).round(),
      1,
    );
  }

  return MaterialColor(color.toARGB32(), swatch);
}
