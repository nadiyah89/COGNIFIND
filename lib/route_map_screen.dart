import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// ---------- Model ----------
class Building {
  final String name;
  final LatLng pos;
  const Building(this.name, this.pos);
}

class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({super.key});
  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  GoogleMapController? _map;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // Selected Source / Destination
  LatLng? _source;
  LatLng? _destination;
  String? _sourceName;
  String? _destName;

  // Current GPS location
  LatLng? _currentLocation;

  // Route info (from backend)
  int? _distanceMeters;    // meters
  int? _durationSeconds;   // seconds
  bool _loadingRoute = false;

  bool _selectingSource = true;

  // Default campus center
  final LatLng _campusCenter = const LatLng(33.98740, 74.94600);

  // Backend endpoint (placeholder)
  // If you use Android emulator to reach your PC's localhost: use 10.0.2.2
  // For real device testing on same WiFi, replace with your PC LAN IP, e.g. http://192.168.1.50:5000
  static const String _backendBase =
      "http:// 192.168.29.243:5000/api/route"; // <-- change when needed

  // Campus buildings (static for now)
  final List<Building> _buildings = const [
    Building('AB-I',   LatLng(33.926356, 75.018919)),
    Building('AB-II',  LatLng(33.925930, 75.018773)),
    Building('AB-III', LatLng(33.925370, 75.019369)),
    Building('AB-IV',  LatLng(33.925280, 75.020203)),
    Building('AB-V',   LatLng(33.924712, 75.020347)),
    Building('AB-VI',  LatLng(33.925493, 75.019497)),
    Building('AB-VII', LatLng(33.925855, 75.020354)),
    Building('AB-X',   LatLng(33.924637, 75.020120)),
    Building('Library',LatLng(33.927098, 75.018474)),
  ];

  CameraPosition get _initialCamera =>
      CameraPosition(target: _campusCenter, zoom: 17);

  @override
  void initState() {
    super.initState();
    _markers.addAll(_buildReferenceMarkers());
  }

  // ---------- MAP MARKERS ----------
  Set<Marker> _buildReferenceMarkers() {
    return _buildings
        .map((b) => Marker(
      markerId: MarkerId('ref_${b.name}'),
      position: b.pos,
      infoWindow: InfoWindow(title: b.name),
      icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure),
      alpha: 0.6,
    ))
        .toSet();
  }

  void _refreshMainMarkers() {
    final all = <Marker>{}..addAll(_buildReferenceMarkers());

    if (_source != null) {
      all.add(Marker(
        markerId: const MarkerId('source'),
        position: _source!,
        infoWindow: const InfoWindow(title: "Source"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    if (_destination != null) {
      all.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destination!,
        infoWindow: const InfoWindow(title: "Destination"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    if (_currentLocation != null) {
      all.add(Marker(
        markerId: const MarkerId('me'),
        position: _currentLocation!,
        infoWindow: const InfoWindow(title: "You are here"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }

    setState(() => _markers
      ..clear()
      ..addAll(all));
  }

  void _centerOn(LatLng p, {double zoom = 18}) {
    _map?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: p, zoom: zoom),
    ));
  }

  void _resetAll() {
    _source = null;
    _destination = null;
    _sourceName = null;
    _destName = null;
    _distanceMeters = null;
    _durationSeconds = null;
    _polylines.clear();
    _refreshMainMarkers();
    _map?.animateCamera(CameraUpdate.newCameraPosition(_initialCamera));
  }

  void _setFromDropdown({required bool isSource, required String name}) {
    final b = _buildings.firstWhere((e) => e.name == name);
    if (isSource) {
      _sourceName = name;
      _source = b.pos;
    } else {
      _destName = name;
      _destination = b.pos;
    }
    _clearRoute(); // clear previous route if changing endpoints
    _centerOn(b.pos);
    _refreshMainMarkers();
  }

  void _onMapTap(LatLng pos) {
    if (_selectingSource) {
      _source = pos;
      _sourceName = null;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Source set from map")));
    } else {
      _destination = pos;
      _destName = null;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Destination set from map")));
    }
    _clearRoute();
    _refreshMainMarkers();
  }

  // ---------- CURRENT LOCATION ----------
  Future<void> _detectCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enable GPS to detect location")));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    _currentLocation = LatLng(pos.latitude, pos.longitude);

    _source = _currentLocation;
    _sourceName = "My Location";
    _clearRoute();
    _centerOn(_currentLocation!);
    _refreshMainMarkers();
  }

  // ---------- ROUTE (BACKEND) ----------
  void _clearRoute() {
    _polylines.clear();
    _distanceMeters = null;
    _durationSeconds = null;
    setState(() {});
  }

  Future<void> _getRouteFromBackend() async {
    if (_source == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please set both Source and Destination")),
      );
      return;
    }

    final url =
        '$_backendBase'
        '?srcLat=${_source!.latitude}&srcLng=${_source!.longitude}'
        '&dstLat=${_destination!.latitude}&dstLng=${_destination!.longitude}';

    try {
      setState(() => _loadingRoute = true);

      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final jsonBody = json.decode(res.body);
      final List<dynamic> route = jsonBody['route'] ?? [];
      final int? distance = jsonBody['distance'];
      final int? duration = jsonBody['duration'];

      if (route.isEmpty) {
        throw Exception('No route points returned');
      }

      final points = route
          .map<LatLng>((p) => LatLng((p['lat'] as num).toDouble(),
          (p['lng'] as num).toDouble()))
          .toList();

      // Build polyline
      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.indigo,
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        points: points,
      );

      setState(() {
        _polylines
          ..clear()
          ..add(polyline);
        _distanceMeters = distance;
        _durationSeconds = duration;
      });

      // Fit camera to route
      _fitToLatLngs(points);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Route error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  void _fitToLatLngs(List<LatLng> pts) {
    if (_map == null || pts.isEmpty) return;

    double minLat = pts.first.latitude;
    double maxLat = pts.first.latitude;
    double minLng = pts.first.longitude;
    double maxLng = pts.first.longitude;

    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _map!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  // ---------- UI HELPERS ----------
  String _formatDistance(int? meters) {
    if (meters == null) return '';
    if (meters >= 1000) {
      final km = (meters / 1000.0);
      return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
    }
    return '$meters m';
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '';
    final mins = (seconds / 60).ceil();
    if (mins >= 60) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m == 0 ? '$h hr' : '$h hr $m min';
    }
    return '$mins min';
  }

  Widget _roundFab({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldStyle = (String hint, IconData icon) => InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white,
    );

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            onMapCreated: (c) => _map = c,
            markers: _markers,
            polylines: _polylines,
            onTap: _onMapTap,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Loading chip (when fetching route)
          if (_loadingRoute)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: Chip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text("Fetching route...")
                  ],
                ),
              ),
            ),

          // ---------- TOP PANEL (your original UI) ----------
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            right: 12,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // SOURCE
                    Row(
                      children: [
                        const Icon(Icons.trip_origin, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _sourceName == "My Location" ? null : _sourceName,
                            decoration: fieldStyle("From (select or tap)", Icons.place),
                            items: _buildings
                                .map((b) => DropdownMenuItem(
                              value: b.name,
                              child: Text(b.name),
                            ))
                                .toList(),
                            onChanged: (val) => val != null
                                ? _setFromDropdown(isSource: true, name: val)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() => _selectingSource = true),
                          child: CircleAvatar(
                            backgroundColor:
                            _selectingSource ? Colors.green : Colors.grey.shade300,
                            child: const Icon(Icons.touch_app,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(Icons.arrow_downward, color: Colors.indigo),
                    ),
                    const SizedBox(height: 10),

                    // DESTINATION
                    Row(
                      children: [
                        const Icon(Icons.flag, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _destName,
                            decoration:
                            fieldStyle("To (select or tap)", Icons.location_on),
                            items: _buildings
                                .map((b) => DropdownMenuItem(
                              value: b.name,
                              child: Text(b.name),
                            ))
                                .toList(),
                            onChanged: (val) => val != null
                                ? _setFromDropdown(isSource: false, name: val)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() => _selectingSource = false),
                          child: CircleAvatar(
                            backgroundColor:
                            !_selectingSource ? Colors.red : Colors.grey.shade300,
                            child: const Icon(Icons.touch_app,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---------- RIGHT FABS (your original order + zoom) ----------
          Positioned(
            right: 12,
            bottom: 110,
            child: Column(
              children: [
                _roundFab(
                    icon: Icons.my_location,
                    color: Colors.indigo,
                    onTap: _detectCurrentLocation),
                const SizedBox(height: 10),
                _roundFab(
                    icon: Icons.center_focus_strong,
                    color: Colors.indigo,
                    onTap: () => _centerOn(_campusCenter)),
                const SizedBox(height: 10),
                _roundFab(
                    icon: Icons.swap_vert,
                    color: Colors.indigo,
                    onTap: () {
                      final tempPos = _source;
                      final tempName = _sourceName;
                      _source = _destination;
                      _sourceName = _destName;
                      _destination = tempPos;
                      _destName = tempName;
                      _clearRoute();
                      _refreshMainMarkers();
                    }),
                const SizedBox(height: 10),
                _roundFab(
                    icon: Icons.clear,
                    color: Colors.black,
                    onTap: _resetAll),
                const SizedBox(height: 10),
                _roundFab(
                    icon: Icons.add,
                    color: Colors.indigo,
                    onTap: () => _map?.animateCamera(CameraUpdate.zoomIn())),
                const SizedBox(height: 10),
                _roundFab(
                    icon: Icons.remove,
                    color: Colors.indigo,
                    onTap: () => _map?.animateCamera(CameraUpdate.zoomOut())),
              ],
            ),
          ),

          // ---------- BOTTOM: ROUTE BUTTON + INFO ----------
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_distanceMeters != null && _durationSeconds != null)
                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 14,
                      ),
                      child: Text(
                        'Distance: ${_formatDistance(_distanceMeters)} • '
                            'Time: ${_formatDuration(_durationSeconds)}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.alt_route),
                  label: const Text("Get Directions"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loadingRoute ? null : _getRouteFromBackend,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
