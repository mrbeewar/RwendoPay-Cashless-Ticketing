import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'auth/login_screen.dart';
import 'passenger/passenger_dashboard.dart';
import 'conductor/conductor_dashboard.dart';
import 'admin/admin_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Listen to Firebase Authentication State
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {

        // If still loading the auth state
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 2. If the user is NOT logged in, show the Login Screen
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        // 3. If logged in, fetch their specific role from the database
        final String uid = authSnapshot.data!.uid;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, userSnapshot) {
            
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // STUCK PROTECTION: If doc doesn't exist, show a way to log out
            if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      const Text("Setting up your profile...", style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 10),
                      const Text("If this takes too long, your profile might be missing.",
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 30),
                      TextButton.icon(
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text("Sign Out & Try Again", style: TextStyle(color: Colors.red)),
                        onPressed: () => FirebaseAuth.instance.signOut(),
                      )
                    ],
                  ),
                ),
              );
            }

            // Convert the raw data into our clean UserModel
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final UserModel currentUser = UserModel.fromMap(userData, uid);

            // 4. ROUTE TO THE CORRECT DASHBOARD
            if (currentUser.role == 'conductor') {
              return const ConductorDashboard();
            } else if (currentUser.role == 'admin') {
              return const AdminDashboard();
            } else {
              return const PassengerDashboard();
            }
          },
        );
      },
    );
  }
}