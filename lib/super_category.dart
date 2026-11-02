import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'create_super_category.dart';

class SuperCategoriesPage extends StatefulWidget {
  const SuperCategoriesPage({super.key});

  @override
  State<SuperCategoriesPage> createState() => _SuperCategoriesPageState();
}

class _SuperCategoriesPageState extends State<SuperCategoriesPage> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text("Please sign in"));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('categories')
              .doc(user!.uid)
              .collection('category')
              .where('deleted', isEqualTo: false)
              .snapshots(),
          builder: (context, catSnapshot) {
            if (catSnapshot.connectionState == ConnectionState.waiting && !catSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            Map<String, String> categoryIdToName = {};
            if (catSnapshot.hasData) {
              for (var doc in catSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                categoryIdToName[doc.id] = data['name'] ?? '';
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('super_categories')
                  .doc(user!.uid)
                  .collection('super_category')
                  .where('deleted', isEqualTo: false)
                  .snapshots(),
              builder: (context, groupSnapshot) {
                if (groupSnapshot.connectionState == ConnectionState.waiting && !groupSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final groups = (groupSnapshot.data?.docs ?? []).toList();
                groups.sort((a, b) {
                  String nameA = (a.data() as Map)['name'] ?? '';
                  String nameB = (b.data() as Map)['name'] ?? '';
                  return nameA.toLowerCase().compareTo(nameB.toLowerCase());
                });

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('record')
                      .where('userId', isEqualTo: user!.uid)
                      .where('deleted', isEqualTo: false)
                      .orderBy('date')
                      .snapshots(),
                  builder: (context, recordSnapshot) {
                    if (recordSnapshot.connectionState == ConnectionState.waiting && !recordSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allRecords = recordSnapshot.data?.docs ?? [];

                    double globalIncome = 0;
                    double globalExpense = 0;
                    double ungroupedNetTotal = 0;

                    Set<String> groupedIds = {};
                    Set<String> groupedNames = {};
                    for (var g in groups) {
                      final gData = g.data() as Map<String, dynamic>;
                      final ids = List<String>.from(gData['subCategoryIds'] ?? []);
                      groupedIds.addAll(ids);
                      for (var id in ids) {
                        if (categoryIdToName.containsKey(id)) {
                          groupedNames.add(categoryIdToName[id]!);
                        }
                      }
                    }

                    for (var doc in allRecords) {
                      final r = doc.data() as Map<String, dynamic>;
                      final type = r['type'];
                      if (type == 'transfer') continue;

                      final amt = (r['amount'] ?? 0).toDouble();
                      final catId = r['categoryId'];
                      final catName = categoryIdToName[catId];

                      if (type == 'expense') globalExpense += amt;
                      else if (type == 'income') globalIncome += amt;

                      bool isGrouped = groupedIds.contains(catId) || groupedNames.contains(catName);
                      if (!isGrouped) {
                        if (type == 'expense') ungroupedNetTotal -= amt;
                        else if (type == 'income') ungroupedNetTotal += amt;
                      }
                    }

                    return Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 24, bottom: 12),
                          child: Text(
                            "Category Groups",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                          ),
                        ),

                        // --- Summary Card ---
                        Container(
                          margin: const EdgeInsets.all(14),
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF673AB7), Color(0xFF512DA8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.deepPurple.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "TOTAL BALANCE",
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "RM ${(globalIncome - globalExpense).toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                            itemCount: groups.length + 1,
                            itemBuilder: (context, index) {
                              if (index == groups.length) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.layers_clear_rounded, color: Colors.grey, size: 20),
                                    ),
                                    title: const Text("Ungrouped", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                                    subtitle: const Text("Remaining categories", style: TextStyle(fontSize: 12)),
                                    trailing: Text(
                                      "RM ${ungroupedNetTotal.toStringAsFixed(2)}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: ungroupedNetTotal >= 0 ? Colors.green.shade400 : Colors.red.shade400
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final groupDoc = groups[index];
                              final groupData = groupDoc.data() as Map<String, dynamic>;
                              final subCatIds = List<String>.from(groupData['subCategoryIds'] ?? []);
                              List<String> subCatNames = subCatIds.map((id) => categoryIdToName[id] ?? '').where((n) => n.isNotEmpty).toList();

                              final recordsInGroup = allRecords.where((doc) {
                                final r = doc.data() as Map<String, dynamic>;
                                return subCatIds.contains(r['categoryId']) || subCatNames.contains(categoryIdToName[r['categoryId']]);
                              }).toList();

                              double groupTotal = 0;
                              for (var doc in recordsInGroup) {
                                final r = doc.data() as Map<String, dynamic>;
                                if (r['type'] == 'transfer') continue;
                                double amt = (r['amount'] ?? 0).toDouble();
                                if (r['type'] == 'expense') groupTotal -= amt;
                                else groupTotal += amt;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    leading: groupData['imageBase64'] != null
                                        ? CircleAvatar(
                                            radius: 20,
                                            backgroundImage: MemoryImage(base64Decode(groupData['imageBase64'])),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(color: Colors.purpleAccent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                                            child: const Icon(Icons.folder_copy_rounded, color: Colors.purpleAccent, size: 20),
                                          ),
                                    title: Text(groupData['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    subtitle: Text("${subCatIds.length} categories included", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                    trailing: Text(
                                      "RM ${groupTotal.toStringAsFixed(2)}",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: groupTotal >= 0 ? Colors.green : Colors.red
                                      ),
                                    ),
                                    children: [
                                      if (recordsInGroup.isNotEmpty)
                                        ...recordsInGroup.map((doc) {
                                          final r = doc.data() as Map<String, dynamic>;
                                          return ListTile(
                                            dense: true,
                                            title: Text(categoryIdToName[r['categoryId']] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                            subtitle: Text(r['dateStr'] ?? ''),
                                            trailing: Text(
                                                "RM ${(r['amount'] ?? 0).toStringAsFixed(2)}",
                                                style: TextStyle(color: r['type'] == 'expense' ? Colors.red : Colors.green)
                                            ),
                                          );
                                        }).toList()
                                      else
                                        const Padding(
                                          padding: EdgeInsets.all(20.0),
                                          child: Text("No records found in this group", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                        ),
                                      const Divider(indent: 16, endIndent: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => CreateSuperCategoryPage(
                                                    groupId: groupDoc.id,
                                                    initialData: groupData,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.deepPurple),
                                            label: const Text("Edit Details", style: TextStyle(color: Colors.deepPurple, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => _deleteGroup(groupDoc.id),
                                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                            label: const Text("Delete Group", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),
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
          heroTag: 'super_category_fab',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateSuperCategoryPage()),
            );
          },
          backgroundColor: Colors.purpleAccent,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text("New Group", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  void _deleteGroup(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Group?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("This will only delete the group container, not your records or categories."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('super_categories')
                  .doc(user!.uid)
                  .collection('super_category')
                  .doc(id)
                  .update({'deleted': true});
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
