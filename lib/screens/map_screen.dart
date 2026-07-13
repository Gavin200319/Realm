import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/drop.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import 'drop_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  Position? _position;
  List<Drop> _drops = [];
  StreamSubscription<Position>? _positionSub;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Set Mapbox token before map initializes
    MapboxOptions.setAccessToken(dotenv.env['MAPBOX_ACCESS_TOKEN']!);
    _initLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      final position = await LocationService.instance.getCurrentPosition();
      setState(() => _position = position);
      await _loadDrops(position);

      _positionSub = LocationService.instance.watchPosition().listen((pos) {
        setState(() => _position = pos);
        _updateUserIndicator(pos);
      });
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  Future<void> _loadDrops(Position position) async {
    try {
      final drops = await SupabaseService.instance.fetchNearbyDrops(
        lat: position.latitude,
        lng: position.longitude,
        radiusM: 10000, // 10km radius on map
      );
      setState(() => _drops = drops);
      if (_mapboxMap != null && _ready) {
        await _updateDropPins();
      }
    } catch (e) {
      debugPrint('Drops load error: $e');
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Disable irrelevant gestures
    await mapboxMap.gestures.updateSettings(
      GesturesSettings(rotateEnabled: false, pitchEnabled: false),
    );

    // Hide Mapbox logo / attribution to keep UI clean (allowed for dev)
    await mapboxMap.logo.updateSettings(LogoSettings(enabled: false));
    await mapboxMap.attribution
        .updateSettings(AttributionSettings(enabled: false));

    // Enable location puck (blue dot showing user position)
    await mapboxMap.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: 0xFF6C4FF6,
    ));

    setState(() => _ready = true);

    // Add drop pin source + layers
    await _setupDropLayers();

    // If location was already fetched before map was ready, add pins now
    if (_position != null) {
      await _updateDropPins();
      await _flyToUser();
    }
  }

  Future<void> _setupDropLayers() async {
    final map = _mapboxMap;
    if (map == null) return;

    // GeoJSON source for drops
    await map.style.addSource(GeoJsonSource(
      id: 'drops-source',
      data: json.encode(_buildGeoJson([])),
    ));

    // Locked drops — grey circle
    await map.style.addLayer(CircleLayer(
      id: 'drops-locked',
      sourceId: 'drops-source',
      filter: ['==', ['get', 'unlocked'], false],
      circleRadius: 12.0,
      circleColor: 0xFF9E9E9E,
      circleStrokeWidth: 2.0,
      circleStrokeColor: 0xFFFFFFFF,
    ));

    // Unlocked drops — purple circle
    await map.style.addLayer(CircleLayer(
      id: 'drops-unlocked',
      sourceId: 'drops-source',
      filter: ['==', ['get', 'unlocked'], true],
      circleRadius: 14.0,
      circleColor: 0xFF6C4FF6,
      circleStrokeWidth: 2.0,
      circleStrokeColor: 0xFFFFFFFF,
    ));

    // Lock icon text on locked drops
    await map.style.addLayer(SymbolLayer(
      id: 'drops-locked-icon',
      sourceId: 'drops-source',
      filter: ['==', ['get', 'unlocked'], false],
      textField: '🔒',
      textSize: 10.0,
      textAllowOverlap: true,
    ));

    // Register tap listener on drop circles
    map.onMapTapListener = (MapContentGestureContext context) async {
      await _handleMapTap(context);
    };
  }

  Future<void> _handleMapTap(MapContentGestureContext context) async {
    final map = _mapboxMap;
    if (map == null || _position == null) return;

    // Query features near tap point
    final features = await map.queryRenderedFeatures(
      RenderedQueryGeometry.fromScreenCoordinate(context.touchPosition),
      RenderedQueryOptions(layerIds: ['drops-locked', 'drops-unlocked']),
    );

    if (features.isEmpty) return;

    final props = features.first?.queriedFeature.feature['properties'];
    if (props == null) return;

    final dropId = props['id'] as String?;
    if (dropId == null) return;

    final drop = _drops.firstWhere(
      (d) => d.id == dropId,
      orElse: () => throw Exception('Drop not found'),
    );

    if (!mounted) return;
    await Navigator.of(context.context ?? this.context).push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          drop: drop,
          currentLat: _position!.latitude,
          currentLng: _position!.longitude,
        ),
      ),
    );
    await _loadDrops(_position!);
  }

  Future<void> _updateDropPins() async {
    final map = _mapboxMap;
    if (map == null || !_ready) return;

    try {
      await map.style.setStyleSourceProperty(
        'drops-source',
        'data',
        json.encode(_buildGeoJson(_drops)),
      );
    } catch (e) {
      debugPrint('Pin update error: $e');
    }
  }

  Map<String, dynamic> _buildGeoJson(List<Drop> drops) {
    return {
      'type': 'FeatureCollection',
      'features': drops
          .where((d) => d.dropLat != null && d.dropLng != null)
          .map((d) => {
                'type': 'Feature',
                'geometry': {
                  'type': 'Point',
                  'coordinates': [d.dropLng!, d.dropLat!],
                },
                'properties': {
                  'id': d.id,
                  'unlocked': d.isUnlocked,
                  'caption': d.caption ?? '',
                  'distance': d.distanceM,
                },
              })
          .toList(),
    };
  }

  Future<void> _flyToUser() async {
    final map = _mapboxMap;
    final pos = _position;
    if (map == null || pos == null) return;

    await map.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(pos.longitude, pos.latitude),
        ),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  Future<void> _updateUserIndicator(Position pos) async {
    // Location puck updates automatically via the location component
    // No manual update needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: _onMapCreated,
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(
                  _position?.longitude ?? 36.8219, // Nairobi default
                  _position?.latitude ?? -1.2921,
                ),
              ),
              zoom: 14.0,
            ),
          ),
          // Drop count badge
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_drops.length} drops nearby',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
          // Re-center button
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'recenter',
              onPressed: _flyToUser,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
