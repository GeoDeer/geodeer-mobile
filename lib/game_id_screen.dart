import 'package:flutter/material.dart';
import 'main.dart';        // LoginScreen main.dart'da tanımlıysa
import 'services/game_screen.dart'; // game_screen dosyası

class GameIdScreen extends StatelessWidget {
  const GameIdScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      // Üstte geri dönme butonu içeren AppBar
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // LoginScreen'e geri dönme
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
        ),
        backgroundColor: Colors.white,
        // foregroundColor: ikon ve metin rengi
        foregroundColor: const Color(0xFF296B45),
        elevation: 0, // Gölgeyi kaldırmak için
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/logo_geodeer.png',
                  width: size.width * 0.4,
                ),
                const SizedBox(height: 40),

                // Tek parça (kutucuk + buton) widget
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF296B45)), // Dark Green
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        // Game ID TextField
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Game ID',
                                border: InputBorder.none, // TextField çerçevesini kapat
                              ),
                            ),
                          ),
                        ),

                        // Sağdaki Buton (Ok)
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF296B45), // Dark Green
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(7),
                              bottomRight: Radius.circular(7),
                            ),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const GameScreen()),
                              );
                            },

                            icon: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
