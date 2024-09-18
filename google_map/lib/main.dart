import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; // Sử dụng geolocator để xử lý quyền vị trí

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const GoogleMapScreen(),
    );
  }
}

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({Key? key}) : super(key: key);

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  GoogleMapController? mapController; // nullable để tránh lỗi LateInitializationError
  bool _isPermissionGranted = false;
  late Position _currentPosition;

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(37.77483, -122.41942), // Toạ độ mặc định của San Francisco
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  // Hàm kiểm tra quyền vị trí
  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Quyền vẫn bị từ chối
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Người dùng đã từ chối vĩnh viễn
      return;
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      setState(() {
        _isPermissionGranted = true;
      });
      _getCurrentLocation();
    }
  }

  // Lấy vị trí hiện tại
  Future<void> _getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      // Di chuyển camera đến vị trí hiện tại khi có mapController
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition.latitude, _currentPosition.longitude),
            zoom: 15.0,
          ),
        ),
      );
    } catch (e) {
      print("Lỗi khi lấy vị trí hiện tại: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Google Maps Example"),
      ),
      body: _isPermissionGranted
          ?GoogleMap(
        mapType: MapType.normal,  // Hiển thị đầy đủ các chi tiết như đường và tòa nhà
        initialCameraPosition: _kInitialPosition,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
          mapController = controller;
          _getCurrentLocation();
        },
        myLocationEnabled: true,  // Hiển thị vị trí hiện tại của người dùng
        myLocationButtonEnabled: true,  // Nút quay về vị trí hiện tại
      )
          : const Center(
        child: Text('Yêu cầu quyền truy cập vị trí để hiển thị bản đồ.'),
      ),
    );
  }
}
