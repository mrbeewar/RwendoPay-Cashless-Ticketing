import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0; // Tracks which sidebar menu is active

  // =========================================================================
  // ADMIN ACTIONS: WITHDRAW FUNDS
  // =========================================================================
  Future<void> _processWithdrawal(String accountRef, double amount) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      // 1. Simulate the Bank/EcoCash Payout API delay
      await Future.delayed(const Duration(seconds: 3));

      int amountInCents = (amount * 100).toInt();

      // 2. Log the withdrawal in the transaction ledger
      await FirebaseFirestore.instance.collection('transactions').add({
        'type': 'payout_withdrawal',
        'amount': amountInCents,
        'destinationAccount': accountRef,
        'status': 'completed',
        'adminId': FirebaseAuth.instance.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Close loading spinner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Successfully withdrew \$${amount.toStringAsFixed(2)} to $accountRef"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Withdrawal failed. Check network."), backgroundColor: Colors.red));
      }
    }
  }

  void _showWithdrawDialog() {
    final amountCtrl = TextEditingController();
    final accountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Withdraw Fleet Revenue"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Transfer funds from the RwendoPay system to a registered corporate bank or EcoCash account.", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: amountCtrl, 
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Amount to Withdraw (USD)", prefixIcon: Icon(Icons.attach_money))
            ),
            const SizedBox(height: 15),
            TextField(
              controller: accountCtrl, 
              decoration: const InputDecoration(labelText: "Destination (EcoCash # or Bank Acc)", prefixIcon: Icon(Icons.account_balance))
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
            onPressed: () {
              final double? amount = double.tryParse(amountCtrl.text);
              if (amount != null && amount > 0 && accountCtrl.text.isNotEmpty) {
                Navigator.pop(context); // Close dialog
                _processWithdrawal(accountCtrl.text.trim(), amount);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter valid details."), backgroundColor: Colors.red));
              }
            },
            child: const Text("Initiate Transfer"),
          )
        ],
      ),
    );
  }

  // =========================================================================
  // ADMIN ACTIONS: CREATE A CONDUCTOR
  // =========================================================================
  Future<void> _registerConductor(BuildContext context, String email, String password, String phone) async {
    // ⚠️ REPLACE THE TEXT BELOW WITH YOUR FIREBASE WEB API KEY ⚠️
    const String apiKey = "AIzaSyCnlje27l4fBUdhTKw9D2MN68aSyh3LjKs";

    try {
      final response = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey'),
        body: jsonEncode({'email': email, 'password': password, 'returnSecureToken': true}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final String newUid = responseData['localId'];

        await FirebaseFirestore.instance.collection('users').doc(newUid).set({
          'uid': newUid,
          'email': email,
          'phoneNumber': phone,
          'role': 'conductor',
          'registeredAt': FieldValue.serverTimestamp(),
        });

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Conductor added!"), backgroundColor: Colors.green));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseData['error']['message']), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network error."), backgroundColor: Colors.red));
    }
  }

  void _showAddConductorDialog() {
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Register New Conductor"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Employee Email")),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Phone Number")),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: "Temporary Password")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _registerConductor(context, emailCtrl.text.trim(), passCtrl.text.trim(), phoneCtrl.text.trim());
            },
            child: const Text("Create Account"),
          )
        ],
      ),
    );
  }

  // =========================================================================
  // MAIN UI BUILDING
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("RwendoPay HQ - Admin Portal", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. DYNAMIC SIDEBAR
          Container(
            width: 250,
            color: Colors.white,
            child: ListView(
              children: [
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text("Live Dashboard"),
                  selected: _selectedIndex == 0,
                  selectedTileColor: Colors.blue[50],
                  selectedColor: Colors.blue[800],
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                ListTile(
                  leading: const Icon(Icons.directions_bus),
                  title: const Text("Fleet Management"),
                  selected: _selectedIndex == 1,
                  selectedTileColor: Colors.blue[50],
                  selectedColor: Colors.blue[800],
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                  title: const Text("Withdraw Funds"),
                  onTap: _showWithdrawDialog,
                ),
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.green),
                  title: const Text("Add Conductor"),
                  onTap: _showAddConductorDialog,
                ),
              ],
            ),
          ),

          // 2. MAIN CONTENT SWITCHER
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: _selectedIndex == 0 ? _buildDashboardView() : _buildFleetView(),
            ),
          )
        ],
      ),
    );
  }

  // =========================================================================
  // VIEW 1: THE DASHBOARD (Analytics & Global Ledger)
  // =========================================================================
  Widget _buildDashboardView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("System Overview", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            // THE NEW WITHDRAW BUTTON
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800], 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)
              ),
              icon: const Icon(Icons.account_balance_wallet),
              label: const Text("Withdraw Funds", style: TextStyle(fontSize: 16)),
              onPressed: _showWithdrawDialog, // Triggers our new popup
            )
          ],
        ),
        const SizedBox(height: 30),

        // LIVE METRICS CARDS
        Row(
          children: [
            Expanded(child: _buildActiveKombisStatCard()),
            const SizedBox(width: 20),
            Expanded(child: _buildTotalRevenueStatCard()),
          ],
        ),

        const SizedBox(height: 40),
        const Text("Global Transaction Ledger", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: _buildTransactionTable(),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // VIEW 2: FLEET MANAGEMENT (Active Kombis)
  // =========================================================================
  Widget _buildFleetView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Active Fleet Monitoring", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text("Monitor kombis currently executing trips across the city in real-time.", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 30),

        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: StreamBuilder<QuerySnapshot>(
              // Query only active bus sessions
              stream: FirebaseFirestore.instance.collection('conductor_sessions').where('status', isEqualTo: 'active').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No active trips right now."));

                return SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                    columns: const [
                      DataColumn(label: Text("Session ID", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Route", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Conductor ID", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Current Revenue", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: snapshot.data!.docs.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      double collected = (data['totalCollected'] ?? 0) / 100.0;

                      return DataRow(cells: [
                        DataCell(Text(doc.id.substring(0, 8).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                        DataCell(Text(data['routeId'] ?? 'Unknown')),
                        DataCell(Text(data['conductorId']?.toString().substring(0, 8) ?? 'N/A')),
                        DataCell(Text("\$${collected.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                        DataCell(Row(children: const [Icon(Icons.circle, color: Colors.green, size: 12), SizedBox(width: 8), Text("On Route")])),
                      ]);
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // HELPER WIDGETS FOR LIVE DATA
  // =========================================================================

  // Real-time stat card for active kombis
  Widget _buildActiveKombisStatCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('conductor_sessions').where('status', isEqualTo: 'active').snapshots(),
      builder: (context, snapshot) {
        int activeCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return _buildStatCard("Active Kombis on Route", activeCount.toString(), Icons.directions_bus, Colors.orange);
      },
    );
  }

  // Real-time stat card aggregating revenue
  Widget _buildTotalRevenueStatCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('conductor_sessions').snapshots(),
      builder: (context, snapshot) {
        double totalRevenue = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            totalRevenue += ((doc.data() as Map<String, dynamic>)['totalCollected'] ?? 0) / 100.0;
          }
        }
        return _buildStatCard("Total System Revenue", "\$${totalRevenue.toStringAsFixed(2)}", Icons.account_balance, Colors.green);
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: color.withOpacity(0.7)),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 5),
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTransactionTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('transactions').orderBy('createdAt', descending: true).limit(50).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No transactions yet."));

        return SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text("Type")),
              DataColumn(label: Text("Amount")),
              DataColumn(label: Text("Reference")),
            ],
            rows: snapshot.data!.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              double amount = (data['amount'] ?? 0) / 100.0;
              
              String type = data['type'] ?? 'unknown';
              Color statusColor = Colors.blue;
              String displayType = "Fare Payment";
              String reference = data['passengerId']?.toString().substring(0, 8) ?? "System";

              if (type == 'top_up') {
                statusColor = Colors.green;
                displayType = "Passenger Top Up";
              } else if (type == 'payout_withdrawal') {
                statusColor = Colors.purple;
                displayType = "Admin Withdrawal";
                reference = data['destinationAccount'] ?? "Bank Transfer";
              }

              return DataRow(cells: [
                DataCell(Text(displayType, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
                DataCell(Text("\$${amount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(reference)),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }
}