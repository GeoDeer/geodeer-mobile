import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latLng;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Oyun ekranı
class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Haritayı kontrol etmek için bir MapController
  final MapController _mapController = MapController();

  // Fallback olarak kullanılacak koordinatlar (örneğin Beytepe)
  final latLng.LatLng _fallbackCenter =
  latLng.LatLng(39.867682455753155, 32.73461274442698);

  // Oyuncunun güncel konumu
  latLng.LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Waypoint bilgileri (örneğin, game=1 için çekilen)
  List<Map<String, dynamic>> _waypoints = [];
  int _currentWaypointIndex = 0;

  // Q/A popup yeniden açılabilsin diye bir flag
  bool _questionPopupShown = false;

  // Geri sayım süresi (1 saat = 3600sn)
  int _remainingSeconds = 3600;
  Timer? _countdownTimer;
  bool _gameEnded = false;

  @override
  void initState() {
    super.initState();
    _initLocationTracking();
    _startCountdown();
    _fetchWaypoints();
  }

  /// Kullanıcının konumunu dinler
  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Konum servisleri kapalı');
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Konum izni reddedildi');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Konum izni kalıcı olarak reddedildi');
      return;
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (!_gameEnded) {
        setState(() {
          _currentPosition =
              latLng.LatLng(position.latitude, position.longitude);
          // Kullanıcının konumuna haritayı kaydır
          _mapController.move(_currentPosition!, _mapController.zoom);
        });

        // Waypoint ile mesafe kontrolü -> Otomatik Q/A popup
        if (_waypoints.isNotEmpty && _currentPosition != null) {
          final lat = double.tryParse(
              _waypoints[_currentWaypointIndex]['lat'].toString()) ??
              0.0;
          final lon = double.tryParse(
              _waypoints[_currentWaypointIndex]['lon'].toString()) ??
              0.0;
          latLng.LatLng waypointPos = latLng.LatLng(lat, lon);

          final distance = latLng.Distance().as(
              latLng.LengthUnit.Meter, _currentPosition!, waypointPos);
          if (distance < 50 && !_questionPopupShown) {
            _questionPopupShown = true;
            showQuestionPopup(context);
          }
        }
      }
    });
  }

  /// Geri sayımı başlatır (1 saat)
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        setState(() {
          _gameEnded = true;
        });
        _countdownTimer?.cancel();
        _showGameOverPopup();
      }
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Sunucudan waypoint bilgilerini alır (örnek: game=1)
  Future<void> _fetchWaypoints() async {
    final url = Uri.parse('https://geodeer.onrender.com/api/waypoints/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final filtered = data.where((e) => e['game'] == 1).toList();
        setState(() {
          _waypoints = filtered.cast<Map<String, dynamic>>();
          _currentWaypointIndex = 0;
        });
      } else {
        debugPrint("Waypoint fetch hata: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Waypoint çekilirken hata: $e");
    }
  }

  /// Format: MM:SS
  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// İki koordinat arasındaki yön (bearing)
  double _calculateBearing(latLng.LatLng start, latLng.LatLng end) {
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final dLon = (end.longitude - start.longitude) * pi / 180;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  /// Markers
  List<Marker> _buildMarkers() {
    List<Marker> markers = [];
    if (_currentPosition != null) {
      // Oyuncu ikonu + ok
      markers.add(
        Marker(
          point: _currentPosition!,
          width: 50,
          height: 80,
          builder: (ctx) {
            // Oyuncu ikonu
            Widget playerIcon = Image.asset(
              'assets/images/1.png',
              width: 40,
              height: 40,
            );

            if (_waypoints.isNotEmpty) {
              final lat = double.tryParse(
                  _waypoints[_currentWaypointIndex]['lat'].toString()) ??
                  0.0;
              final lon = double.tryParse(
                  _waypoints[_currentWaypointIndex]['lon'].toString()) ??
                  0.0;
              latLng.LatLng waypointPos = latLng.LatLng(lat, lon);
              final distance = latLng.Distance().as(
                  latLng.LengthUnit.Meter, _currentPosition!, waypointPos);

              Color arrowColor;
              double arrowLength;
              if (distance < 250) {
                arrowColor = Colors.green;
                arrowLength = 20;
              } else if (distance < 750) {
                arrowColor = Colors.orange;
                arrowLength = 30;
              } else {
                arrowColor = Colors.red;
                arrowLength = 40;
              }
              final bearing = _calculateBearing(_currentPosition!, waypointPos);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  playerIcon,
                  const SizedBox(height: 4),
                  Material(
                    color: Colors.transparent,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Transform.rotate(
                      angle: bearing * (pi / 180),
                      child: Icon(
                        Icons.arrow_upward,
                        color: arrowColor,
                        size: arrowLength,
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return playerIcon;
            }
          },
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    // Eğer henüz kullanıcı konumu alınmamışsa, yükleniyor göstergesi göster
    if (_currentPosition == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Harita katmanı: center olarak sadece _currentPosition kullanılır.
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentPosition!,
              zoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: _buildMarkers(),
              ),
            ],
          ),
          // Diğer widgetlar (geri sayım, HINT, Q/A butonları, vs.)
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatTime(_remainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          // Sağ üstte HINT butonu
          Positioned(
            top: 40,
            right: 20,
            child: ElevatedButton(
              onPressed: _gameEnded ? null : () => showHintPopup(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7F50),
              ),
              child: const Text(
                'HINT',
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
            ),
          ),
          // Sol üstte Q/A butonu (devre dışı; otomatik popup ile kontrol ediliyor)
          Positioned(
            top: 40,
            left: 20,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7F50).withOpacity(0.5),
              ),
              child: const Text(
                'Q/A',
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
            ),
          ),
          // Sağ kenarda Yakınlaşma/Uzaklaşma butonları
          Positioned(
            right: 7,
            top: 665,
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _gameEnded
                      ? null
                      : () {
                    final zoom = _mapController.zoom + 1;
                    _mapController.move(_mapController.center, zoom);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7F50),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(10),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _gameEnded
                      ? null
                      : () {
                    final zoom = _mapController.zoom - 1;
                    _mapController.move(_mapController.center, zoom);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7F50),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(10),
                  ),
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
              ],
            ),
          ),
          // Sağ alt: konumu ortala butonu
          Positioned(
            bottom: 40,
            right: 10,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFFFF7F50),
              onPressed: _gameEnded
                  ? null
                  : () {
                _mapController.move(_currentPosition!, 16.0);
              },
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
          // Oyun sona erdiğinde overlay
          if (_gameEnded)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Text(
                  'Game Over',
                  style: TextStyle(
                    color: Colors.red[300],
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  /// HINT popup
  void showHintPopup(BuildContext context) {
    String hintText = "No hint available.";
    if (_waypoints.isNotEmpty) {
      final map = _waypoints[_currentWaypointIndex];
      hintText = (map['hint'] ?? "No hint").toString();
    }
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF296B45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Hint',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            hintText,
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// Q/A popup
  void showQuestionPopup(BuildContext context) {
    String questionText = "No question available.";
    String correctAnswer = "";
    if (_waypoints.isNotEmpty) {
      final map = _waypoints[_currentWaypointIndex];
      if (map['question'] != null) {
        questionText = map['question'].toString();
      }
      if (map['answer'] != null) {
        correctAnswer = map['answer'].toString();
      }
    }

    final answerController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false, // kapatılamasın
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF296B45),
          title: const Text(
            'Question',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(questionText, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 10),
              TextField(
                controller: answerController,
                decoration: const InputDecoration(
                  labelText: 'Your Answer',
                  labelStyle: TextStyle(color: Colors.white),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final userAnswer =
                answerController.text.trim().toLowerCase();
                final expectedAnswer = correctAnswer.trim().toLowerCase();
                Navigator.pop(ctx);

                if (userAnswer.isNotEmpty && userAnswer == expectedAnswer) {
                  // Doğru cevap
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Correct answer!")),
                  );
                  setState(() {
                    if (_currentWaypointIndex < _waypoints.length - 1) {
                      _currentWaypointIndex++;
                      _questionPopupShown = false;
                    } else {
                      _gameEnded = true;
                    }
                  });
                  if (!_gameEnded && _currentWaypointIndex < _waypoints.length) {
                    Future.delayed(const Duration(milliseconds: 500), () {
                      showHintPopup(context);
                    });
                  }
                } else {
                  // Yanlış cevap
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Wrong answer. Try again!")),
                  );
                  setState(() {
                    _questionPopupShown = false;
                  });
                  // Tekrar sorabilmek için buffer kontrol ediyorsanız:
                  if (_isInBuffer()) {
                    Future.delayed(const Duration(seconds: 1), () {
                      showQuestionPopup(context);
                    });
                  }
                }
              },
              child: const Text(
                'SUBMIT',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Oyun sona erdiğinde popup
  void _showGameOverPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Game Over'),
          content: const Text('Time is up. The game has ended.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Buffer içinde mi?
  bool _isInBuffer() {
    if (_currentPosition != null && _waypoints.isNotEmpty) {
      final lat = double.tryParse(
          _waypoints[_currentWaypointIndex]['lat'].toString()) ??
          0.0;
      final lon = double.tryParse(
          _waypoints[_currentWaypointIndex]['lon'].toString()) ??
          0.0;
      latLng.LatLng waypointPos = latLng.LatLng(lat, lon);
      final distance = latLng.Distance().as(
          latLng.LengthUnit.Meter, _currentPosition!, waypointPos);
      return distance < 50;
    }
    return false;
    }
}
