// about_page.dart
import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('About'),
        backgroundColor: Colors.blue[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Aplikasi ini dibuat oleh Kelompok 5:\n'
                'Jordan Roring,\n'
                'Christiansen Liot,\n'
                'Kenzy Rumimper,\n'
                'Gerald Pangau,\n'
                'Loraine Dondo',
                semanticsLabel: 'Anggota Kelompok',
                style: TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                'Tugas Rekayasa Perangkat Lunak',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              // Tambahkan informasi lain sesuai kebutuhan
            ],
          ),
        ),
      ),
    );
  }
}