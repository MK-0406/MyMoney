import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';


class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final user = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();

  Future<void> _addNewAccount() async {
    XFile? pickedImage;
    _nameController.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text("New Account", style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 100, maxHeight: 100, imageQuality: 50);
                    if (image != null) setDialogState(() => pickedImage = image);
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey.shade100,
                    backgroundImage: pickedImage != null ? FileImage(File(pickedImage!.path)) : null,
                    child: pickedImage == null ? const Icon(Icons.add_a_photo, color: Colors.grey) : null,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: "Account Name",
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    )
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (_nameController.text.isEmpty) return;
                  String? base64;
                  if (pickedImage != null) base64 = base64Encode(await pickedImage!.readAsBytes());

                  await FirebaseFirestore.instance.collection('accounts').doc(user!.uid).collection('account').add({
                    'name': _nameController.text.trim(),
                    'imageBase64': base64,
                    'createdAt': FieldValue.serverTimestamp(),
                    'deleted': false,
                    'balance': 0,
                    'totalExpense': 0,
                    'totalIncome': 0
                  });
                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editAccount(String docId, String name, String? existingImage) async {
    String? pickedImage = existingImage;
    _nameController.text = name;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text("Edit Account", style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 100, maxHeight: 100, imageQuality: 50);
                    if (image != null) {
                      String bytes = base64Encode(await image.readAsBytes());
                      setDialogState(() => pickedImage = bytes);
                    }
                  },
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey.shade100,
                    backgroundImage: pickedImage != null ? MemoryImage(base64Decode(pickedImage!)) : null,
                    child: pickedImage == null ? const Icon(Icons.add_a_photo, color: Colors.grey) : null,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: "Account Name",
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    )
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (_nameController.text.isEmpty) return;

                  await FirebaseFirestore.instance.collection('accounts').doc(user!.uid).collection('account').doc(docId).update({
                    'name': _nameController.text.trim(),
                    'imageBase64': pickedImage,
                  });
                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteAccount(String docId, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool deletable = data['balance'] == 0 && data['totalExpense'] == 0 && data['totalIncome'] == 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Account", style: TextStyle(fontWeight: FontWeight.bold)),
        content: deletable ? Text("Are you sure to remove this account?") : Text("Please make sure there is no record under this account before deleting."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => deletable ? Navigator.pop(context, true) : null,
            child: Text("Delete", style: TextStyle(color: deletable ? Colors.red : Colors.grey, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final recordRef = FirebaseFirestore.instance
            .collection('accounts')
            .doc(user.uid)
            .collection('account')
            .doc(docId);

        batch.update(recordRef, {'deleted': true});

        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account deleted successfully"), backgroundColor: Colors.purpleAccent,));
        }
      } catch (e) {
        debugPrint("Delete Error: $e");
      }
    }
  }

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
              .where('deleted', isEqualTo: false)
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

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),

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
                            data['id'] = docs[index].id;
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
                                    color: Colors.black.withValues(alpha: 0.02),
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
                                onTap: () {
                                  _editAccount(data['id'], name, imageBase64);
                                },
                                onLongPress: () {
                                  _deleteAccount(data['id'], data);
                                },
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton.extended(
          heroTag: 'accounts_fab',
          onPressed: _addNewAccount,
          backgroundColor: Colors.purple,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text("New Account", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
