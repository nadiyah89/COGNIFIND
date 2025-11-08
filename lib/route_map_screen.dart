import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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

  // Default campus center
  final LatLng _campusCenter = const LatLng(33.98740, 74.94600);

  // Campus buildings (static for now)
  final List<Building> _buildings = const [
    Building('AB-I', LatLng(33.926356, 75.018919)),
    Building('AB-II', LatLng(33.92593, 75.018773)),
    Building('AB-III', LatLng(33.925370, 75.019369)),
    Building('AB-IV', LatLng(33.925280, 75.020203)),
    Building('AB-V', LatLng(33.924712, 75.020347)),
    Building('AB-VI', LatLng(33.925493, 75.019497)),
    Building('AB-VII', LatLng(33.925855, 75.020354)),
    Building('AB-X', LatLng(33.924637, 75.020120)),
    Building('Library', LatLng(33.927098, 75.018474)),
  ];

  // Selected Source / Destination
  LatLng? _source;
  LatLng? _destination;
  String? _sourceName;
  String? _destName;

  // Current GPS location
  LatLng? _currentLocation;

  bool _selectingSource = true;

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
        icon:
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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

  void _centerOn(LatLng p) {
    _map?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: p, zoom: 18),
    ));
  }

  void _resetAll() {
    _source = null;
    _destination = null;
    _sourceName = null;
    _destName = null;
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Destination set from map")));
    }
    _refreshMainMarkers();
  }

  // ---------- GET CURRENT LOCATION ----------
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

    // Auto-fill source
    _source = _currentLocation;
    _sourceName = "My Location";

    _centerOn(_currentLocation!);
    _refreshMainMarkers();
  }

  // ---------- GET DIRECTIONS ----------
  void _onGetDirections() {
    if (_source == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please set both Source and Destination")),
      );
      return;
    }

    // TODO later: call .NET backend here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            "Route: ${_source!.latitude},${_source!.longitude} → ${_destination!.latitude},${_destination!.longitude}"),
      ),
    );
  }

  Widget _roundFab(
      {required IconData icon,
        required Color color,
        required VoidCallback onTap}) {
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
            onTap: _onMapTap,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
          ),

          // ---------- TOP PANEL ----------
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
                    // Source
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
                            onChanged: (val) =>
                            val != null ? _setFromDropdown(isSource: true, name: val) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() => _selectingSource = true),
                          child: CircleAvatar(
                            backgroundColor:
                            _selectingSource ? Colors.green : Colors.grey.shade300,
                            child:
                            const Icon(Icons.touch_app, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Align(alignment: Alignment.centerLeft,
                        child: Icon(Icons.arrow_downward, color: Colors.indigo)),
                    const SizedBox(height: 10),

                    // Destination
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
                            child:
                            const Icon(Icons.touch_app, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---------- RIGHT FABS ----------
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
                      _refreshMainMarkers();
                    }),
                const SizedBox(height: 10),
                _roundFab(
                    icon: Icons.clear,
                    color: Colors.black,
                    onTap: _resetAll),
              ],
            ),
          ),

          // ---------- BOTTOM BUTTON ----------
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: ElevatedButton.icon(
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
              onPressed: _onGetDirections,
            ),
          ),
        ],
      ),
    );
  }
}
