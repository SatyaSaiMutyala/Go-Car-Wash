
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  LatLng? selectedPosition;
  String? selectedAddress;
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLocate();
  }

  Future<void> _checkPermissionAndLocate() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => isLoading = true);

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      await _handleMapTap(currentLatLng);

      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: currentLatLng, zoom: 17),
          ),
        );
      }

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Location error: $e")));
    }
  }

  Future<void> _handleMapTap(LatLng position) async {
    setState(() {
      selectedPosition = position;
      selectedAddress = null;
      isLoading = true;
    });

    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first;
        selectedAddress =
            "${p.name}, ${p.locality}, ${p.administrativeArea}, ${p.country}";
      }
    } catch (e) {
      selectedAddress = "Unknown location";
    }

    setState(() => isLoading = false);
  }

  Future<void> _searchLocation() async {
    FocusScope.of(context).unfocus(); // Hide keyboard
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    try {
      setState(() => isLoading = true);
      List<Location> locations = await locationFromAddress(query);

      if (locations.isNotEmpty) {
        final loc = locations.first;
        LatLng newLatLng = LatLng(loc.latitude, loc.longitude);
  
        await _handleMapTap(newLatLng);

        mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: newLatLng, zoom: 17),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location not found")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Search error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose Location"),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          )
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(20.5937, 78.9629),
              zoom: 5,
            ),
            onMapCreated: (controller) {
              mapController = controller;
              if (selectedPosition != null) {
                mapController!.animateCamera(
                  CameraUpdate.newLatLngZoom(selectedPosition!, 17),
                );
              }
            },
            onTap: _handleMapTap,
            markers: selectedPosition != null
                ? {
                    Marker(
                      markerId: const MarkerId("selected"),
                      position: selectedPosition!,
                    )
                  }
                : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),

          // 🔍 Search Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchLocation(),
                      decoration: const InputDecoration(
                        hintText: "Search city, area or street...",
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchLocation,
                  ),
                ],
              ),
            ),
          ),

          if (isLoading) const Center(child: CircularProgressIndicator()),

          if (selectedAddress != null && !isLoading)
            Positioned(
              bottom: 80,
              left: 20,
              right: 20,
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    selectedAddress!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: selectedPosition == null
                  ? null
                  : () {
                      Navigator.pop(context, {
                        "address": selectedAddress,
                        "latitude": selectedPosition!.latitude,
                        "longitude": selectedPosition!.longitude,
                      });
                    },
              child: const Text("Set This Location"),
            ),
          ),
        ],
      ),
    );
  }
}
