import 'dart:async'; // For asynchronous programming
import 'package:flutter/material.dart'; // Flutter material design widgets
import 'package:firebase_auth/firebase_auth.dart'; // Firebase authentication
import 'package:firebase_database/firebase_database.dart'; // Firebase Realtime Database
import 'login.dart'; // Adjust the path as necessary
import 'main.dart'; // Assuming you have a MapPage to navigate to

class AccountSettings extends StatefulWidget {
  final Function(String) onVehicleInfoUpdated; // Callback function
  final FirebaseAuth auth; // Pass the auth instance
  final String? username; // Pass username
  final String? email; // Pass email

  const AccountSettings({
    Key? key,
    required this.onVehicleInfoUpdated,
    required this.auth,
    this.username,
    this.email,
  }) : super(key: key);

  @override
  _AccountSettingsState createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<AccountSettings> {
  String? selectedVehicleType;
  String? selectedFuelType;
  final TextEditingController fuelAmountController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref(); // Corrected initialization

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.currentUser ;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Account Settings'),
          backgroundColor: Colors.blue[900],
        ),
        body: const Center(
          child: Text(
            'No user logged in.',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: Colors.blue[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Profile Section
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue[900],
                  child: Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  widget.username ?? 'Unknown User',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  widget.email ?? 'Unknown Email',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),

              // Vehicle Type Dropdown
              _buildDropdown<String>(
                label: 'Jenis Kendaraan',
                value: selectedVehicleType,
                items: const [
                  DropdownMenuItem(value: 'Daihatsu Ayla', child: Text('Daihatsu Ayla')),
                  DropdownMenuItem(value: 'Honda Vario 160', child: Text('Honda Vario 160')),
                  DropdownMenuItem(value: 'Daihatsu Xenia', child: Text('Daihatsu Xenia')),
                  DropdownMenuItem(value: 'Toyota Avanza', child: Text('Toyota Avanza')),
                  DropdownMenuItem(value: 'Yamaha NMAX', child: Text('Yamaha NMAX')),
                  DropdownMenuItem(value: 'Honda Beat', child: Text('Honda Beat')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedVehicleType = value;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Fuel Type Dropdown
              _buildDropdown<String>(
                label: 'Jenis Bensin',
                value: selectedFuelType,
                items: const [
                  DropdownMenuItem(value: 'Pertalite', child: Text('Pertalite')),
                  DropdownMenuItem(value: 'Premium', child: Text('Premium')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedFuelType = value;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Input for Fuel Amount
              TextField(
                controller: fuelAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Bahan Bakar (L )',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Save Button
              ElevatedButton(
                onPressed: () {
                  // Save vehicle and fuel type
                  _database.ref.update({
                    'vehicleType': selectedVehicleType,
                    'fuelType': selectedFuelType,
                    'fuelAmount': fuelAmountController.text, // Save fuel amount
                  }).then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Data berhasil disimpan')),
                    );
                    String updatedVehicleInfo = 'Kendaraan: $selectedVehicleType\nJenis Bensin: $selectedFuelType\nJumlah Bahan Bakar: ${fuelAmountController.text} L';
                    widget.onVehicleInfoUpdated(updatedVehicleInfo); // Panggil callback

                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const MapPage()),
                    );
                  }).catchError((error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $error')),
                    );
                  });
                },
                child: const Text('Simpan'),
              ),
              const SizedBox(height: 10),

              // Logout Button
              ElevatedButton(
                onPressed: () async {
                  await widget.auth.signOut();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You have logged out.')),
                  );
                  Future.delayed(const Duration(seconds: 1), () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                      (route) => false,
                    );
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
  required String label,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return Form(
    child: DropdownButtonFormField<T>(
      value: value,
      onChanged: onChanged,
      items: items,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    ),
  );
}
}
