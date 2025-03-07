// signup_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'main.dart'; 

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  String? selectedVehicleType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: Colors.blue[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Fuely',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedVehicleType,
              onChanged: (value) {
                setState(() {
                  selectedVehicleType = value;
                });
              },
              items: const [
                DropdownMenuItem(value: 'Daihatsu Ayla', child: Text('Daihatsu Ayla')),
                DropdownMenuItem(value: 'Honda Vario 160', child: Text('Honda Vario 160')),
                DropdownMenuItem(value: 'Daihatsu Xenia', child: Text('Daihatsu Xenia')),
                DropdownMenuItem(value: 'Toyota Avanza', child: Text('Toyota Avanza')),
                DropdownMenuItem(value: 'Yamaha NMAX', child: Text('Yamaha NMAX')),
                DropdownMenuItem(value: 'Honda Beat', child: Text('Honda Beat')),
              ],
              decoration: const InputDecoration(
                labelText: 'Jenis Kendaraan',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  UserCredential result = await _auth.createUserWithEmailAndPassword(
                    email: emailController.text,
                    password: passwordController.text,
                  );
                  User? user = result.user;

                  if (user != null) {
                    _database.ref('users/${user.uid}').set({
                      'username': usernameController.text,
                      'email': emailController.text,
                      'vehicleType': selectedVehicleType,
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account created successfully!')),
                    );

                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const MapPage()),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to create account')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Sign Up'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Go back to LoginPage
              },
              child: const Text('Already have an account? Login '),
            ),
          ],
        ),
      ),
    );
  }
}