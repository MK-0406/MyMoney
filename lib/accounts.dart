import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text("Please sign in"));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('accounts')
              .doc(user!.uid)
              .collection('account')
              .orderBy('name')
              .snapshots(),
          builder: (context, accountSnapshot) {
            if (accountSnapshot.hasError) return Center(child: Text("Error: ${accountSnapshot.error}"));
            if (accountSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = accountSnapshot.data?.docs ?? [];
            
            double globalBalance = 0;
            double globalIncome = 0;
            double globalExpense = 0;

            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              globalBalance += (data['balance'] ?? 0.0).toDouble();
              globalIncome += (data['totalIncome'] ?? 0.0).toDouble();
              globalExpense += (data['totalExpense'] ?? 0.0).toDouble();
            }

            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 20, bottom: 10),
                  child: Text(
                    "Accounts",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),

                // --- Global Summary Section ---
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  // FIX: Added IntrinsicHeight to prevent display errors on strict devices
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem("TOTAL", globalBalance, Colors.blue),
                        const VerticalDivider(thickness: 1, indent: 5, endIndent: 5),
                        _buildSummaryItem("INCOME", globalIncome, Colors.green),
                        const VerticalDivider(thickness: 1, indent: 5, endIndent: 5),
                        _buildSummaryItem("EXPENSE", globalExpense, Colors.red),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: docs.isEmpty
                      ? const Center(child: Text("No accounts found"))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final name = data['name'] ?? data['Game1'] ?? 'Unknown';
                            final imageBase64 = data['imageBase64'];
                            final balance = (data['balance'] ?? 0.0).toDouble();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: imageBase64 != null
                                    ? CircleAvatar(
                                        radius: 25,
                                        backgroundImage: MemoryImage(base64Decode(imageBase64)),
                                      )
                                    : const CircleAvatar(
                                        radius: 25,
                                        child: Icon(Icons.account_balance_wallet),
                                      ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                trailing: Text(
                                  "RM ${balance.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: balance >= 0 ? Colors.green : Colors.red,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Text(
          "RM ${amount.toStringAsFixed(2)}",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
