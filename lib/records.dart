import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'new_record.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  DateTime selectedDate = DateTime.now();
  late String yearSelected;
  late String monthSelected;
  late String monthIndex;

  String? selectedAccount;
  String? selectedCategory;

  Map<String, String> accountList = {};
  Map<String, String> categoryList = {};

  @override
  void initState() {
    super.initState();
    _updateDateStrings();
  }

  void _updateDateStrings() {
    yearSelected = selectedDate.year.toString();
    monthSelected = DateFormat('MMMM').format(selectedDate);
    monthIndex = selectedDate.month.toString();
  }

  Future<void> _deleteRecord(String docId, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Record", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure? This will remove the record and reverse the amount from your account balance."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final recordRef = FirebaseFirestore.instance
            .collection('records')
            .doc(user.uid)
            .collection('year')
            .doc(yearSelected)
            .collection('month')
            .doc(monthIndex)
            .collection('record')
            .doc(docId);

        final amount = (data['amount'] ?? 0) as num;
        final type = data['type'];

        if (type == 'transfer') {
          // REVERSE TRANSFER: Reverse both accounts using stored IDs
          final fromAccountId = data['accountId'];
          final toAccountId = data['toAccountId'];

          if (fromAccountId != null) {
            final fromRef = FirebaseFirestore.instance.collection('accounts').doc(user.uid).collection('account').doc(fromAccountId);
            batch.update(fromRef, {'balance': FieldValue.increment(amount.toDouble())});
          }

          if (toAccountId != null) {
            final toRef = FirebaseFirestore.instance.collection('accounts').doc(user.uid).collection('account').doc(toAccountId);
            batch.update(toRef, {'balance': FieldValue.increment(-amount.toDouble())});
          }
        } else {
          // REVERSE INCOME/EXPENSE using stored accountId
          final accountId = data['accountId'];
          if (accountId != null) {
            final accountRef = FirebaseFirestore.instance.collection('accounts').doc(user.uid).collection('account').doc(accountId);
            double balanceChange = type == 'income' ? -amount.toDouble() : amount.toDouble();
            
            batch.update(accountRef, {
              'balance': FieldValue.increment(balanceChange),
              'totalIncome': type == 'income' ? FieldValue.increment(-amount.toDouble()) : FieldValue.increment(0.0),
              'totalExpense': type == 'expense' ? FieldValue.increment(-amount.toDouble()) : FieldValue.increment(0.0),
            });
          }
        }

        // Soft delete the record
        batch.update(recordRef, {'deleted': true});
        
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Record deleted successfully")));
        }
      } catch (e) {
        debugPrint("Delete Error: $e");
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 50),
          Icon(Icons.receipt_long_rounded, size: 80, color: Colors.deepPurple.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          const Text("No records match your filters", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey)),
          const Text("Try changing your selection", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRecordCard(String docId, Map<String, dynamic> record, Map<String, String> categoryImages) {
    String type = record['type'] ?? 'expense';
    record['category'] = categoryList[record['categoryId']] ?? 'General';
    String? categoryImage = categoryImages[record['category']];
    bool isTransfer = type == 'transfer';
    record['account'] = accountList[record['accountId']];
    isTransfer ? record['toAccount'] = accountList[record['toAccountId']] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateRecordPage(recordId: docId, initialData: record))),
        onLongPress: () => _deleteRecord(docId, record),
        leading: isTransfer
            ? Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.swap_horiz_rounded, color: Colors.blue),
              )
            : (categoryImage != null && categoryImage.isNotEmpty
                ? Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(image: MemoryImage(base64Decode(categoryImage)), fit: BoxFit.cover),
                    ),
                  )
                : Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: Colors.deepPurple.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.category_rounded, color: Colors.deepPurple),
                  )),
        title: Text(isTransfer ? "${record['account']} → ${record['toAccount']}" : record['category'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(isTransfer ? "Transfer" : (record['account'] ?? 'Cash'), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        trailing: Text(
          "RM ${((record['amount'] ?? 0) as num).toDouble().toStringAsFixed(2)}",
          style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 16,
            color: type == 'income' ? Colors.green.shade600 : (type == 'expense' ? Colors.red.shade600 : Colors.blue.shade600),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Please sign in"));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          // Fetch Categories
          stream: FirebaseFirestore.instance.collection('categories').doc(user.uid).collection('category').where('deleted', isEqualTo: false).orderBy('name').snapshots(),
          builder: (context, catSnapshot) {
            Map<String, String> categoryImages = {};
            List<String> categoryNameList = ["All"];
            if (catSnapshot.hasData) {
              for (var doc in catSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['name'] != null) {
                  categoryNameList.add(data['name']);
                  categoryList[doc.id] = data['name'];
                  if (data['imageBase64'] != null) categoryImages[data['name']] = data['imageBase64'];
                }
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('accounts').doc(user.uid).collection('account').where('deleted', isEqualTo: false).orderBy('name').snapshots(),
              builder: (context, accSnapshot) {
                List<String> accountNameList = ["All"];
                if (accSnapshot.hasData) {
                  for (var doc in accSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['name'] != null) {
                      accountNameList.add(data['name']);
                      accountList[doc.id] = data['name'];
                    };
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('records')
                      .doc(user.uid)
                      .collection('year')
                      .doc(yearSelected)
                      .collection('month')
                      .doc(monthIndex)
                      .collection('record')
                      .where('deleted', isEqualTo: false)
                      .orderBy('date', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    List<DocumentSnapshot> allRecords = snapshot.data?.docs ?? [];
                    
                    List<DocumentSnapshot> filteredRecords = allRecords.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      bool accountMatch = selectedAccount == null || selectedAccount == "All" || accountList[data['accountId']] == selectedAccount || accountList[data['toAccountId']] == selectedAccount;
                      bool categoryMatch = selectedCategory == null || selectedCategory == "All" || categoryList[data['categoryId']] == selectedCategory;
                      return accountMatch && categoryMatch;
                    }).toList();

                    double expense = 0, income = 0;
                    for (var doc in filteredRecords) {
                      final data = doc.data() as Map<String, dynamic>;
                      double amt = ((data['amount'] ?? 0) as num).toDouble();
                      if (data['type'] == 'expense') expense += amt;
                      if (data['type'] == 'income') income += amt;
                    }

                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(onPressed: () { setState(() { selectedDate = DateTime(selectedDate.year, selectedDate.month - 1); _updateDateStrings(); }); }, icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), style: IconButton.styleFrom(backgroundColor: Colors.white)),
                              Text("$monthSelected $yearSelected", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                              IconButton(onPressed: () { setState(() { selectedDate = DateTime(selectedDate.year, selectedDate.month + 1); _updateDateStrings(); }); }, icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18), style: IconButton.styleFrom(backgroundColor: Colors.white))
                            ],
                          ),
                        ),
                        
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              _buildFilterChip("Account: ${selectedAccount ?? 'All'}", () => _showFilterDialog("Account", accountNameList, (val) => setState(() => selectedAccount = val))),
                              const SizedBox(width: 8),
                              _buildFilterChip("Category: ${selectedCategory ?? 'All'}", () => _showFilterDialog("Category", categoryNameList, (val) => setState(() => selectedCategory = val))),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple, borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 8))],
                            gradient: const LinearGradient(colors: [Color(0xFF673AB7), Color(0xFF512DA8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildSummaryItem("EXPENSE", expense, Colors.white),
                                VerticalDivider(color: Colors.white.withValues(alpha: 0.2), thickness: 1, indent: 4, endIndent: 4),
                                _buildSummaryItem("INCOME", income, Colors.white),
                                VerticalDivider(color: Colors.white.withValues(alpha: 0.2), thickness: 1, indent: 4, endIndent: 4),
                                _buildSummaryItem("BALANCE", income - expense, Colors.white),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: snapshot.connectionState == ConnectionState.waiting
                              ? const Center(child: CircularProgressIndicator())
                              : filteredRecords.isEmpty
                                  ? _buildEmptyState()
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                                      itemCount: filteredRecords.length,
                                      itemBuilder: (context, index) {
                                        final doc = filteredRecords[index];
                                        final data = doc.data() as Map<String, dynamic>;
                                        bool isNewDay = index == 0 || data['dateStr'] != (filteredRecords[index - 1].data() as Map)['dateStr'];

                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (isNewDay) Padding(padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8), child: Text(data['dateStr'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.bold))),
                                            _buildRecordCard(doc.id, data, categoryImages),
                                          ],
                                        );
                                      },
                                    ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton.extended(
          heroTag: 'records_fab', // UNIQUE TAG
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRecordPage())),
          backgroundColor: Colors.deepPurple, elevation: 4,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text("New", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    return ActionChip(
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.1)),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
      avatar: const Icon(Icons.filter_list_rounded, size: 14, color: Colors.deepPurple),
    );
  }

  void _showFilterDialog(String title, List<String> options, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.all(20), child: Text("Filter by $title", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(options[index]),
                onTap: () { onSelect(options[index]); Navigator.pop(context); },
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Text("RM ${amount.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
    ]);
  }
}
