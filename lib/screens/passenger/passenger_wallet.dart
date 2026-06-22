import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PassengerWalletScreen extends StatefulWidget {
  const PassengerWalletScreen({super.key});

  @override
  State<PassengerWalletScreen> createState() => _PassengerWalletScreenState();
}

class _PassengerWalletScreenState extends State<PassengerWalletScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;

  Future<void> _simulateEcoCashTopUp() async {
    // 1. Input Validation
    if (_amountController.text.isEmpty) return;

    final double? inputAmount = double.tryParse(_amountController.text);
    if (inputAmount == null || inputAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid amount"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. SIMULATE LATENCY: Mimic the 3-second delay of an EcoCash USSD prompt
      await Future.delayed(const Duration(seconds: 3));

      // 3. FINANCIAL PRECISION: Convert dollars to integer cents
      int amountInCents = (inputAmount * 100).toInt();
      final String currentUid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;

      // 4. BATCH WRITE: Safely update the balance AND the ledger at the exact same time
      WriteBatch batch = db.batch();

      // A. Add funds to the user's wallet
      DocumentReference userRef = db.collection('users').doc(currentUid);
      batch.update(userRef, {
        'walletBalance': FieldValue.increment(amountInCents)
      });

      // B. Create an immutable record in the transactions ledger
      DocumentReference txRef = db.collection('transactions').doc();
      batch.set(txRef, {
        'transactionId': txRef.id,
        'type': 'top_up',
        'status': 'completed',
        'amount': amountInCents,
        'passengerId': currentUid,
        'paymentMethod': 'mock_ecocash',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit(); // Execute both operations

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Successfully added \$${inputAmount.toStringAsFixed(2)}!"),
              backgroundColor: Colors.green
          ),
        );
        _amountController.clear();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Top-up failed. Please check your connection."), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Top Up Zimtap Wallet"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.phone_android, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              "Simulate EcoCash Transfer",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Enter an amount in USD to add to your digital wallet. This simulates a mobile money API response.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Amount to Top Up (USD)",
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 30),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _simulateEcoCashTopUp,
              child: const Text("PAY WITH ECOCASH", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}