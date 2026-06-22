import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/crypto_utils.dart';

class PassengerScannerScreen extends StatefulWidget {
  const PassengerScannerScreen({super.key});

  @override
  State<PassengerScannerScreen> createState() => _PassengerScannerScreenState();
}

class _PassengerScannerScreenState extends State<PassengerScannerScreen> {
  bool _isProcessing = false;
  late MobileScannerController _scannerController;

  @override
  void initState() {
    super.initState();
    // 'noDuplicates' ensures we don't scan the same frame multiple times rapidly
    _scannerController = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  // 1. THIS RUNS WHEN THE CAMERA SEES A QR CODE
  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return; // Ignore if we are already processing a payment

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.startsWith("PAY|")) {
        setState(() => _isProcessing = true);
        _scannerController.stop(); // Pause camera immediately

        _showPaymentConfirmation(barcode.rawValue!);
        break; // Stop looking for other barcodes in the frame
      }
    }
  }

  // 2. PARSE THE QR DATA AND ASK FOR CONFIRMATION
  void _showPaymentConfirmation(String qrData) {
    // Expected Format: PAY|sessionId|routeId|fareAmountInCents|signature
    try {
      List<String> parts = qrData.split('|');
      String sessionId = parts[1];
      String routeId = parts[2];
      int fareAmountInCents = int.parse(parts[3]);
      String scannedSignature = parts[4]; // Extract the signature

      // THE CRITICAL SECURITY CHECK
      bool isValid = CryptoUtils.verifyQRSignature(sessionId, routeId, fareAmountInCents, scannedSignature);

      if (!isValid) {
        // If the signatures don't match, someone tampered with the QR code!
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("FRAUD ALERT: Invalid or tampered QR Code!"), backgroundColor: Colors.red)
        );
        _resetScanner();
        return;
      }

      double displayFare = fareAmountInCents / 100.0;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Confirm Payment"),
          content: Text("Pay \$${displayFare.toStringAsFixed(2)} for this trip?", style: const TextStyle(fontSize: 18)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resetScanner(); // User canceled, turn camera back on
              },
              child: const Text("CANCEL", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                _executeAtomicPayment(sessionId, routeId, fareAmountInCents);
              },
              child: const Text("PAY NOW"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid QR Code format.")));
      _resetScanner();
    }
  }

  // 3. THE SECURE ATOMIC TRANSACTION (Our Workaround for the Blaze Plan)
  Future<void> _executeAtomicPayment(String sessionId, String routeId, int fareAmountInCents) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    final String passengerId = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;

    final walletRef = db.collection('users').doc(passengerId); // Wallet balance is inside the user doc for MVP
    final sessionRef = db.collection('conductor_sessions').doc(sessionId);
    final txRef = db.collection('transactions').doc();
    final notifRef = sessionRef.collection('notifications').doc(txRef.id);

    try {
      await db.runTransaction((transaction) async {
        // A. READ Phase
        final walletSnapshot = await transaction.get(walletRef);
        final sessionSnapshot = await transaction.get(sessionRef);

        if (!walletSnapshot.exists) throw Exception("WALLET_NOT_FOUND");
        if (!sessionSnapshot.exists || sessionSnapshot.data()?['status'] != 'active') {
          throw Exception("SESSION_INVALID");
        }

        int currentBalance = walletSnapshot.data()?['walletBalance'] ?? 0;
        int currentTotalCollected = sessionSnapshot.data()?['totalCollected'] ?? 0;

        // B. VALIDATION Phase
        if (currentBalance < fareAmountInCents) throw Exception("INSUFFICIENT_FUNDS");

        // C. WRITE Phase (All or Nothing)
        transaction.update(walletRef, {'walletBalance': currentBalance - fareAmountInCents});
        transaction.update(sessionRef, {'totalCollected': currentTotalCollected + fareAmountInCents});

        transaction.set(txRef, {
          'transactionId': txRef.id,
          'type': "fare_payment",
          'status': "completed",
          'amount': fareAmountInCents,
          'passengerId': passengerId,
          'conductorSessionId': sessionId,
          'routeId': routeId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(notifRef, {
          'transactionId': txRef.id,
          'amount': fareAmountInCents,
          'status': "success",
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      // SUCCESS
      if (mounted) {
        Navigator.pop(context); // Remove loading circle
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fare paid successfully!"), backgroundColor: Colors.green));
        Navigator.pop(context); // Go back to Dashboard
      }

    } on FirebaseException catch (e) {
      if (mounted) {
        Navigator.pop(context); // Remove loading circle
        String errorMsg = "Network Error. Please check your internet connection.";
        
        // Specifically catch Firestore network unreachability
        if (e.code == 'unavailable') {
          errorMsg = "No internet connection. Payment requires a live network to prevent fraud.";
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.orange[800])
        );
        _resetScanner();
      }
    } catch (error) {
      // Catch any other general errors (like our custom INSUFFICIENT_FUNDS)
      if (mounted) {
        Navigator.pop(context); 
        String errorMsg = "Payment failed. Try again.";
        if (error.toString().contains("INSUFFICIENT_FUNDS")) errorMsg = "Insufficient funds! Please top up.";
        if (error.toString().contains("SESSION_INVALID")) errorMsg = "This bus session is no longer active.";

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
        _resetScanner();
      }
    }
  }

  void _resetScanner() {
    setState(() => _isProcessing = false);
    _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Kombi QR"), backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          // A visual targeting box for the user
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 4),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const Positioned(
            bottom: 50,
            child: Text("Align the Conductor's QR code within the frame", style: TextStyle(color: Colors.white, backgroundColor: Colors.black54, fontSize: 16)),
          )
        ],
      ),
    );
  }
}