import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geodeer_mobile/services/location_service.dart';
 // location_service.dart dosyası lib klasörü içerisinde yer alıyor.

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String locationText = "Konum Bekleniyor...";

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      // location_service.dart içindeki determinePosition() fonksiyonunu çağırıyoruz
      Position position = await determinePosition();
      setState(() {
        locationText =
        "Enlem: ${position.latitude}, Boylam: ${position.longitude}";
      });
    } catch (e) {
      setState(() {
        locationText = "Hata: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Konum Testi")),
      body: Center(child: Text(locationText)),
    );
  }
}
