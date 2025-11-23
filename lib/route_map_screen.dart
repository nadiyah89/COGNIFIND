import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'api_client.dart';
import 'models.dart';
import 'dart:convert';

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
  final LatLng _campusCenter = const LatLng(33.98740, 74.94600);

  final List<Building> _buildings = const [
    Building('Academic Block A', LatLng(33.98765, 74.94532)),
    Building('Library', LatLng(33.98712, 74.94588)),
    Building('Admin Block', LatLng(33.98675, 74.94621)),
    Building('Hostel', LatLng(33.98690, 74.94700)),
    Building('Cafeteria', LatLng(33.98780, 74.94510)),
  ];

  LatLng? _source;
  LatLng? _destination;
  String? _sourceName;
  String? _destName;
  LatLng? _currentLocation;

  int? _distanceMeters;
  int? _durationSeconds;
  bool _loading = false;
  bool _selectingSource = true;

  @override
  void initState() {
    super.initState();
    _markers.addAll(_buildReferenceMarkers());
  }

  Set<Marker> _buildReferenceMarkers() => _buildings.map((b) => Marker(markerId: MarkerId('ref_${b.name}'), position: b.pos, infoWindow: InfoWindow(title: b.name), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), alpha: 0.7)).toSet();

  void _refreshMarkers() {
    final all = <Marker>{}..addAll(_buildReferenceMarkers());
    if (_source != null) all.add(Marker(markerId: const MarkerId('src'), position: _source!, infoWindow: const InfoWindow(title: 'Source'), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)));
    if (_destination != null) all.add(Marker(markerId: const MarkerId('dst'), position: _destination!, infoWindow: const InfoWindow(title: 'Destination'), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)));
    if (_currentLocation != null) all.add(Marker(markerId: const MarkerId('me'), position: _currentLocation!, infoWindow: const InfoWindow(title: 'You are here'), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)));
    setState(() {
      _markers
        ..clear()
        ..addAll(all);
    });
  }

  void _onMapTap(LatLng pos) {
    if (_selectingSource) {
      _source = pos;
      _sourceName = null;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source set from map')));
    } else {
      _destination = pos;
      _destName = null;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destination set from map')));
    }
    _polylines.clear();
    _refreshMarkers();
  }

  void _setFromDropdown({required bool isSource, required String name}) {
    final b = _buildings.firstWhere((e) => e.name == name);
    if (isSource) {
      _source = b.pos;
      _sourceName = name;
    } else {
      _destination = b.pos;
      _destName = name;
    }
    _polylines.clear();
    _centerOn(b.pos);
    _refreshMarkers();
  }

  Future<void> _detectLocation() async {
    bool ok = await Geolocator.isLocationServiceEnabled();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable GPS')));
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
    final p = await Geolocator.getCurrentPosition();
    _currentLocation = LatLng(p.latitude, p.longitude);
    _source = _currentLocation;
    _sourceName = 'My Location';
    _polylines.clear();
    _centerOn(_currentLocation!);
    _refreshMarkers();
  }

  void _centerOn(LatLng p, {double zoom = 18}) => _map?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: p, zoom: zoom)));

  Future<void> _getRoute() async {
    if (_source == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set source & destination')));
      return;
    }
    setState(() => _loading = true);
    try {
      // Use ApiClient.get method to include auth header if present
      final path = '/api/maps/directions?srcLat=${_source!.latitude}&srcLng=${_source!.longitude}&dstLat=${_destination!.latitude}&dstLng=${_destination!.longitude}';
      final res = await ApiClient.get(path);
      if (res.statusCode != 200) throw Exception('Server error ${res.statusCode}: ${res.body}');
      final Map<String, dynamic> body = json.decode(res.body);
      final routeResp = RouteResponseModel.fromJson(body);
      final pts = routeResp.route.map((e) => LatLng(e.lat, e.lng)).toList();
      final poly = Polyline(polylineId: const PolylineId('route'), points: pts, color: Colors.indigo, width: 6, jointType: JointType.round);
      setState(() {
        _polylines
          ..clear()
          ..add(poly);
        _distanceMeters = routeResp.distance;
        _durationSeconds = routeResp.duration;
      });
      _fitToBoundsFixed(pts);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Route error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fitToBoundsFixed(List<LatLng> pts) {
    if (_map == null || pts.isEmpty) return;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude, minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
    _map!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  String _fmtDist(int? m) {
    if (m == null) return '';
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
    return '${m} m';
  }

  String _fmtDur(int? s) {
    if (s == null) return '';
    final m = (s / 60).ceil();
    if (m >= 60) {
      final h = m ~/ 60;
      final mm = m % 60;
      return mm == 0 ? '$h hr' : '$h hr $mm min';
    }
    return '$m min';
  }

  Widget _roundFab({required IconData icon, required Color color, required VoidCallback onTap}) => Material(color: color, shape: const CircleBorder(), elevation: 3, child: InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Padding(padding: const EdgeInsets.all(12.0), child: Icon(icon, color: Colors.white, size: 22))));

  @override
  Widget build(BuildContext context) {
    final fieldStyle = (String hint, IconData icon) => InputDecoration(hintText: hint, prefixIcon: Icon(icon), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white);

    return Scaffold(
      appBar: AppBar(title: const Text('CogniFind Navigation'), backgroundColor: Colors.indigo),
      body: Stack(children: [
        GoogleMap(initialCameraPosition: CameraPosition(target: _campusCenter, zoom: 17), onMapCreated: (c) => _map = c, markers: _markers, polylines: _polylines, onTap: _onMapTap, myLocationEnabled: false, zoomControlsEnabled: false),
        Positioned(top: MediaQuery.of(context).padding.top + 12, left: 12, right: 12, child: Material(elevation: 6, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(children: [
          Row(children: [
            const Icon(Icons.trip_origin, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<String>(isExpanded: true, value: _sourceName == 'My Location' ? null : _sourceName, decoration: fieldStyle('From (select or tap)', Icons.place), items: _buildings.map((b) => DropdownMenuItem(value: b.name, child: Text(b.name))).toList(), onChanged: (val) => val != null ? _setFromDropdown(isSource: true, name: val) : null)),
            const SizedBox(width: 8),
            InkWell(onTap: () => setState(() => _selectingSource = true), child: CircleAvatar(backgroundColor: _selectingSource ? Colors.green : Colors.grey.shade300, child: const Icon(Icons.touch_app, color: Colors.white, size: 20)))
          ]),
          const SizedBox(height: 10),
          const Align(alignment: Alignment.centerLeft, child: Icon(Icons.arrow_downward, color: Colors.indigo)),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.flag, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<String>(isExpanded: true, value: _destName, decoration: fieldStyle('To (select or tap)', Icons.location_on), items: _buildings.map((b) => DropdownMenuItem(value: b.name, child: Text(b.name))).toList(), onChanged: (val) => val != null ? _setFromDropdown(isSource: false, name: val) : null)),
            const SizedBox(width: 8),
            InkWell(onTap: () => setState(() => _selectingSource = false), child: CircleAvatar(backgroundColor: !_selectingSource ? Colors.red : Colors.grey.shade300, child: const Icon(Icons.touch_app, color: Colors.white, size: 20)))
          ]),
        ])))),
        Positioned(right: 12, bottom: 110, child: Column(children: [
          _roundFab(icon: Icons.my_location, color: Colors.indigo, onTap: _detectLocation),
          const SizedBox(height: 10),
          _roundFab(icon: Icons.center_focus_strong, color: Colors.indigo, onTap: () => _centerOn(_campusCenter)),
          const SizedBox(height: 10),
          _roundFab(icon: Icons.swap_vert, color: Colors.indigo, onTap: () {
            final tp = _source;
            final tn = _sourceName;
            _source = _destination;
            _sourceName = _destName;
            _destination = tp;
            _destName = tn;
            _polylines.clear();
            _refreshMarkers();
          }),
          const SizedBox(height: 10),
          _roundFab(icon: Icons.clear, color: Colors.black, onTap: () {
            _source = null;
            _destination = null;
            _polylines.clear();
            _refreshMarkers();
          }),
          const SizedBox(height: 10),
          _roundFab(icon: Icons.add, color: Colors.indigo, onTap: () => _map?.animateCamera(CameraUpdate.zoomIn())),
          const SizedBox(height: 10),
          _roundFab(icon: Icons.remove, color: Colors.indigo, onTap: () => _map?.animateCamera(CameraUpdate.zoomOut())),
        ])),
        Positioned(left: 16, right: 16, bottom: 24, child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_distanceMeters != null && _durationSeconds != null)
            Card(elevation: 4, margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14), child: Text('Distance: ${_fmtDist(_distanceMeters)} • Time: ${_fmtDur(_durationSeconds)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
          ElevatedButton.icon(icon: const Icon(Icons.alt_route), label: const Text('Get Directions (Walking)'), style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _loading ? null : _getRoute)
        ]))
      ]),
    );
  }
}
