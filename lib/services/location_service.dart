// location_service.dart
import 'package:geolocator/geolocator.dart';

/// Kullanıcının konumunu belirler.
/// Eğer konum servisleri kapalıysa veya izinler reddedilmişse,
/// uygun hata mesajını Future.error ile döndürür.
Future<Position> determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // 1. Konum servislerinin açık olup olmadığını kontrol et
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Konum servisleri kapalı.');
  }

  // 2. Konum izinlerini kontrol et
  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Konum izinleri reddedildi.');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error('Konum izinleri kalıcı olarak reddedildi.');
  }

  // 3. İzinler verildiyse, konumu al
  return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high);
}
