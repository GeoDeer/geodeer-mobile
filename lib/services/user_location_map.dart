import 'dart:async'; // Timer için gerekli
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User Location Map',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: UserLocationMap(),
    );
  }
}

class UserLocationMap extends StatefulWidget {
  @override
  _UserLocationMapState createState() => _UserLocationMapState();
}

class _UserLocationMapState extends State<UserLocationMap> {
  final MapController _mapController = MapController();
  Marker? _userLocationMarker; // Sadece kullanıcı konumunu tutacak marker
  Timer? _locationTimer;       // 5 saniyede bir konum sorgulamak için timer

  @override
  void initState() {
    super.initState();
    print("initState: Başlatılıyor");
    _startPeriodicLocationUpdates(); // Timer'ı başlatıyoruz
  }

  // ---------------------------------------------------------------------------
  // 1) Konum İzni Kontrolü
  // ---------------------------------------------------------------------------
  Future<void> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Konum servisleri kapalı. Lütfen açınız.');
      // Burada kullanıcıya uyarı gösterilebilir.
    } else {
      print('Konum servisleri açık.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    print("İzin durumu: $permission");
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      print("İzin durumu (istek sonrası): $permission");
      if (permission == LocationPermission.denied) {
        print('Konum izni reddedildi.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Konum izni kalıcı olarak reddedildi. Ayarlardan açmanız gerekiyor.');
    }
  }

  // ---------------------------------------------------------------------------
  // 2) 5 Saniyede Bir Konum Güncellemesi için Timer Kullanımı
  // ---------------------------------------------------------------------------
  Future<void> _startPeriodicLocationUpdates() async {
    // Eğer Timer zaten aktifse, yeniden oluşturmayın.
    if (_locationTimer != null && _locationTimer!.isActive) {
      print("Timer zaten aktif.");
      return;
    }

    print("Timer başlatılıyor...");
    await _checkPermission();

    // Her 5 saniyede bir konum sorgulaması yap
    _locationTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        print('Yeni konum: ${position.latitude}, ${position.longitude} @ ${DateTime.now()}');
        final userLatLng = LatLng(position.latitude, position.longitude);

        // Kullanıcının konumu için özel PNG ikonunu kullanın:
        final newMarker = Marker(
          point: userLatLng,
          width: 50,
          height: 50,
          builder: (ctx) => Image.asset(
            'assets/2.png', // Kendi PNG dosyanızın adını buraya yazın
            width: 50,
            height: 50,
          ),
        );
        setState(() {
          _userLocationMarker = newMarker;
        });
        // Haritayı bu yeni konuma taşıyın
        _mapController.move(userLatLng, 16.0);
      } catch (e) {
        print("Konum alınamadı: $e");
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 3) Widget Temizlenirken Timer'ı Durdurma
  // ---------------------------------------------------------------------------
  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    if (_userLocationMarker != null) {
      markers.add(_userLocationMarker!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('User Location Map'),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          center: LatLng(39.866789, 32.735987),
          zoom: 16.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
          MarkerLayer(markers: markers),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // İsteğe bağlı: Manuel olarak da Timer'ı yeniden başlatabilirsiniz.
          _startPeriodicLocationUpdates();
        },
        child: Icon(Icons.my_location),
      ),
    );
  }
}
