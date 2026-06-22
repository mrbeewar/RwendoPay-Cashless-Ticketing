import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../utils/crypto_utils.dart';

class ConductorDashboard extends StatefulWidget {
  const ConductorDashboard({super.key});

  @override
  State<ConductorDashboard> createState() => _ConductorDashboardState();
}

class _ConductorDashboardState extends State<ConductorDashboard> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  final FirebaseFirestore db = FirebaseFirestore.instance;

  String? activeSessionId;
  String? selectedRouteId;
  int selectedFareInCents = 100; // Default $1.00

  // Hardcoded routes for the MVP prototype
  final List<Map<String, dynamic>> routes = [
    {'id': 'route_avondale', 'name': 'City - Avondale', 'fare': 100}, // $1.00
    {'id': 'route_mbare', 'name': 'City - Mbare', 'fare': 50},       // $0.50
    {'id': 'route_borrowdale', 'name': 'City - Borrowdale', 'fare': 150},// $1.50
  ];

  Future<void> _startShift() async {
    if (selectedRouteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a route first.")));
      return;
    }

    setState(() {
      // Generate a unique ID for this specific bus trip
      activeSessionId = db.collection('conductor_sessions').doc().id;
    });

    // Create the session in the database
    await db.collection('conductor_sessions').doc(activeSessionId).set({
      'sessionId': activeSessionId,
      'conductorId': currentUid,
      'routeId': selectedRouteId,
      'totalCollected': 0,
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _endShift() async {
    if (activeSessionId != null) {
      await db.collection('conductor_sessions').doc(activeSessionId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });
      setState(() {
        activeSessionId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Conductor Terminal", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())
        ],
      ),
      body: activeSessionId == null ? _buildSetupScreen() : _buildActiveSessionScreen(),
    );
  }

  // --- SCREEN 1: BEFORE SHIFT STARTS ---
  Widget _buildSetupScreen() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.directions_bus, size: 80, color: Colors.green),
          const SizedBox(height: 20),
          const Text("Start New Trip", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 30),

          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: "Select Route", border: OutlineInputBorder()),
            items: routes.map((route) {
              double displayFare = route['fare'] / 100.0;
              return DropdownMenuItem<String>(
                value: route['id'],
                child: Text("${route['name']} (\$${displayFare.toStringAsFixed(2)})"),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                selectedRouteId = val;
                selectedFareInCents = routes.firstWhere((r) => r['id'] == val)['fare'];
              });
            },
          ),
          const SizedBox(height: 30),

          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
            onPressed: _startShift,
            child: const Text("GENERATE QR CODE", style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  // --- SCREEN 2: DURING THE SHIFT (ACTIVE QR) ---
  Widget _buildActiveSessionScreen() {
    // This is the string the Passenger App will scan and parse!
    // Generate the un-forgeable signature
    String signature = CryptoUtils.generateQRSignature(activeSessionId!, selectedRouteId!, selectedFareInCents);

    // Append the signature to the end of the QR string
    String qrData = "PAY|$activeSessionId|$selectedRouteId|$selectedFareInCents|$signature";

    return Column(
      children: [
        // Top section: The QR Code
        Container(
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Column(
            children: [
              const Text("SCAN TO PAY FARE", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[100], foregroundColor: Colors.red[800]),
                icon: const Icon(Icons.stop_circle),
                label: const Text("End Shift"),
                onPressed: _endShift,
              )
            ],
          ),
        ),

        // Bottom section: Real-time payment feed
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Live Payments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    // THIS IS THE SECRET TO THE SUB-2-SECOND REQUIREMENT
                    stream: db.collection('conductor_sessions').doc(activeSessionId)
                        .collection('notifications')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                      if (snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("Waiting for passengers to scan..."));
                      }

                      return ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var notif = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          double amountPaid = (notif['amount'] ?? 0) / 100.0;

                          return Card(
                            color: Colors.green[50],
                            child: ListTile(
                              leading: const Icon(Icons.check_circle, color: Colors.green, size: 40),
                              title: const Text("Payment Received", style: TextStyle(fontWeight: FontWeight.bold)),
                              trailing: Text("+\$${amountPaid.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}
