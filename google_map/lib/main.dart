import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Đặt `debugShowCheckedModeBanner` thành false để ẩn biểu ngữ debug
      debugShowCheckedModeBanner: false,
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
  GoogleMapController? mapController;
  bool _isPermissionGranted = false;
  Position? _currentPosition;

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(21.0278, 105.8342), // Hà Nội
    zoom: 10.0,
  );

  Set<Marker> _markers = {};
  LatLng _startLocation = LatLng(21.030653, 105.782942); // Quận Cầu Giấy
  LatLng _endLocation = LatLng(20.973891, 105.777278);   // Quận Hà Đông
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    // Không gọi _getDirections() ở đây nữa
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
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentPosition = position;
      });

      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentLatLng,
            zoom: 15.0,
          ),
        ),
      );

      // Nếu muốn lấy các bệnh viện gần vị trí hiện tại, bạn có thể kích hoạt hàm này
      // _getHospitals(currentLatLng);
    } catch (e) {
      print("Lỗi khi lấy vị trí hiện tại: $e");
    }
  }

  Future<void> _getHospitals(LatLng userLocation) async {
    // Hàm này đang bị vô hiệu hóa. Nếu muốn sử dụng, hãy thêm API Key và kích hoạt lại
    // String apiKey = 'YOUR_API_KEY'; // Thay bằng API Key của bạn
    // ...
  }

  // Hàm lấy chỉ đường
  Future<void> _getDirections() async {
    try
    {
      String apiKey = 'AIzaSyAAmSIrSdA8A2ovKuss11u2SQkZnW6-Kxk'; // Thay bằng API Key của bạn
      String origin = '${_startLocation.latitude},${_startLocation.longitude}';
      String destination = '${_endLocation.latitude},${_endLocation.longitude}';

      String url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$apiKey';

      http.Response response = await http.get(Uri.parse(url));
      Map data = jsonDecode(response.body);

      if (data['status'] == 'OK') {
        String encodedPolyline = data['routes'][0]['overview_polyline']['points'];
        List<PointLatLng> points = PolylinePoints().decodePolyline(encodedPolyline);

        List<LatLng> polylineCoordinates = points.map((point) {
          return LatLng(point.latitude, point.longitude);
        }).toList();

        setState(() {
          _polylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: polylineCoordinates,
            color: Colors.blue,
            width: 5,
          ));

          // Thêm marker cho điểm bắt đầu và kết thúc
          _markers.add(Marker(
            markerId: const MarkerId('start'),
            position: _startLocation,
            infoWindow: const InfoWindow(title: 'Quận Cầu Giấy'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ));
          _markers.add(Marker(
            markerId: const MarkerId('end'),
            position: _endLocation,
            infoWindow: const InfoWindow(title: 'Quận Hà Đông'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ));
        });

        // Di chuyển camera để hiển thị toàn bộ tuyến đường
        mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            _getBounds(_startLocation, _endLocation),
            50,
          ),
        );
      } else {
        print('Lỗi khi lấy chỉ đường: ${data['status']}');
      }
    }
    catch (e) {
      print('Lỗi ngoại lệ khi gọi Directions API: $e');
    }
  }

  // Hàm tính toán giới hạn hiển thị bản đồ
  LatLngBounds _getBounds(LatLng start, LatLng end) {
    return LatLngBounds(
      southwest: LatLng(
        start.latitude < end.latitude ? start.latitude : end.latitude,
        start.longitude < end.longitude ? start.longitude : end.longitude,
      ),
      northeast: LatLng(
        start.latitude > end.latitude ? start.latitude : end.latitude,
        start.longitude > end.longitude ? start.longitude : end.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Đường đi từ Cầu Giấy đến Hà Đông"),
      ),
      body: _isPermissionGranted
          ? GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _kInitialPosition,
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
          mapController = controller;
          if (_currentPosition == null) {
            _getCurrentLocation();
          }
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        markers: _markers,
        polylines: _polylines,
      )
          : const Center(
        child: Text('Yêu cầu quyền truy cập vị trí để hiển thị bản đồ.'),
      ),
      // Thêm nút FloatingActionButton
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Khi nhấn nút, gọi hàm _getDirections()
          _getDirections();
        },
        child: const Icon(Icons.navigation),
        tooltip: 'Vẽ đường đi',
      ),
    );
  }
}
