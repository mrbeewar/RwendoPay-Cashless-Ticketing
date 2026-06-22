import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'passenger_wallet.dart';
import 'passenger_scanner.dart';

class PassengerDashboard extends StatelessWidget {
  const PassengerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Safely grab the current user ID for the Firestore stream
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('My Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Premium Wallet Card (Now powered by Firestore!)
            _buildLiveWalletCard(currentUid, context),

            const SizedBox(height: 40),

            // 2. Giant Scan Button (Now wired to your scanner screen)
            SizedBox(
              height: 80,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PassengerScannerScreen())
                  );
                },
                icon: const Icon(Icons.qr_code_scanner, size: 36, color: Colors.white),
                label: const Text(
                    'SCAN TICKET TO PAY',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600, // High contrast for action
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 4,
                ),
              ),
            ),

            const SizedBox(height: 30),
            const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),

            // 3. Placeholder for Transaction List
            Expanded(
              child: Center(
                child: Text('Your recent trips will appear here.', style: TextStyle(color: Colors.grey.shade500)),
                // TODO: Replace this Center with your ListView.builder pulling from Firestore
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Merged: The UI from Snippet 2 wrapped in the StreamBuilder from Snippet 1
  Widget _buildLiveWalletCard(String uid, BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        // Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.teal.shade800,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        // Data processing logic kept exactly as you had it
        int balanceInCents = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          balanceInCents = data['walletBalance'] ?? 0;
        }

        double displayBalance = balanceInCents / 100.0;

        // Premium UI Output
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade800, Colors.teal.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AVAILABLE BALANCE', style: TextStyle(color: Colors.white70, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text(
                  '\$${displayBalance.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PassengerWalletScreen())
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Top Up', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const Icon(Icons.contactless, color: Colors.white, size: 32),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}