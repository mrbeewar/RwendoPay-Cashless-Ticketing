import 'dart:convert';
import 'package:crypto/crypto.dart';

class CryptoUtils {
  // ACADEMIC NOTE: In a true production app, this secret key would ONLY live on your
  // Node.js Cloud Functions. Because we shifted to a client-side atomic transaction
  // to avoid billing, we are using a shared client secret. You should mention this
  // compromise in your FYP documentation!
  static const String _secretKey = "Zimtap_Super_Secret_FYP_Key_2026!";

  /// Generates a secure hash based on the trip details
  static String generateQRSignature(String sessionId, String routeId, int fareInCents) {
    // 1. Combine the data into a single string
    final String payload = "$sessionId|$routeId|$fareInCents";

    // 2. Convert to bytes
    final List<int> keyBytes = utf8.encode(_secretKey);
    final List<int> messageBytes = utf8.encode(payload);

    // 3. Generate the HMAC-SHA256 Hash
    final Hmac hmac = Hmac(sha256, keyBytes);
    final Digest digest = hmac.convert(messageBytes);

    // 4. Return the hexadecimal string
    return digest.toString();
  }

  /// Verifies if a scanned QR code has been tampered with
  static bool verifyQRSignature(String sessionId, String routeId, int fareInCents, String scannedSignature) {
    final String expectedSignature = generateQRSignature(sessionId, routeId, fareInCents);
    return expectedSignature == scannedSignature;
  }
}