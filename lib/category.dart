import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>>? categoriesData;
  double incomeTotal = 0, expenseTotal = 0;
  bool isLoading = true;
  String? errorMessage;
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (user == null) return;
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 1. Fetch Categories (removed orderBy to avoid Index requirement)
      final categoriesRef = await FirebaseFirestore.instance
          .collection('categories')
          .doc(user!.uid)
          .collection('category')
          .where('deleted', isEqualTo: false)
          .get();

      List<Map<String, dynamic>> tempCategories = categoriesRef.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        data['balance'] = 0.0;
        data['type'] ??= 'expense'; // Default for old categories
        return data;
      }).toList();

      // Sort categories by name in memory
      tempCategories.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

      // 2. Fetch Records for balance calculation
      final recordsRef = await FirebaseFirestore.instance
          .collectionGroup('record')
          .where('userId', isEqualTo: user!.uid)
          .where('deleted', isEqualTo: false)
          .get();

      double tempIncome = 0;
      double tempExpense = 0;

      for (var doc in recordsRef.docs) {
        final record = doc.data();
        final amt = (record['amount'] ?? 0).toDouble();
        final type = record['type'];
        final catId = record['categoryId'];
        final catName = record['category'];

        for (var category in tempCategories) {
          if (catId == category['id'] || (catId == null && catName == category['name'])) {
            if (type == 'income') {
              tempIncome += amt;
              category['balance'] += amt;
            } else if (type == 'expense') {
              tempExpense += amt;
              category['balance'] -= amt;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          categoriesData = tempCategories;
          incomeTotal = tempIncome;
          expenseTotal = tempExpense;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading categories: $e");
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<void> _addNewCategory() async {
    XFile? pickedImage;
    _nameController.clear();
    String currentType = _tabController.index == 0 ? 'expense' : 'income';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text("New ${currentType[0].toUpperCase()}${currentType.substring(1)} Category", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    hintText: "Category Name", 
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
                  
                  await FirebaseFirestore.instance.collection('categories').doc(user!.uid).collection('category').add({
                    'name': _nameController.text.trim(),
                    'imageBase64': base64,
                    'type': currentType,
                    'createdAt': FieldValue.serverTimestamp(),
                    'deleted': false,
                  });
                  Navigator.pop(context);
                  _initializeData();
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryList(String type) {
    final filtered = categoriesData?.where((cat) => cat['type'] == type).toList() ?? [];

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.purpleAccent.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text("No $type categories found", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _initializeData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final data = filtered[index];
          final balance = (data['balance'] ?? 0.0).toDouble();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: data['imageBase64'] != null
                  ? CircleAvatar(radius: 24, backgroundImage: MemoryImage(base64Decode(data['imageBase64'])))
                  : CircleAvatar(radius: 24, backgroundColor: Colors.purpleAccent.withOpacity(0.05), child: const Icon(Icons.category_rounded, color: Colors.purpleAccent)),
              title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(
                "RM ${balance.abs().toStringAsFixed(2)}",
                style: TextStyle(fontWeight: FontWeight.bold, color: balance >= 0 ? Colors.green : Colors.red, fontSize: 16),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text("Please sign in"));
    
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text("Failed to load data", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _initializeData, child: const Text("Retry")),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 24, bottom: 8),
              child: Text("Categories", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            ),
            
            // Summary Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purpleAccent,
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(colors: [Color(0xFF8E24AA), Color(0xFFD81B60)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem("TOTAL", incomeTotal - expenseTotal, Colors.white),
                    VerticalDivider(color: Colors.white.withOpacity(0.3), thickness: 1, indent: 4, endIndent: 4),
                    _buildSummaryItem("INCOME", incomeTotal, Colors.white),
                    VerticalDivider(color: Colors.white.withOpacity(0.3), thickness: 1, indent: 4, endIndent: 4),
                    _buildSummaryItem("EXPENSE", expenseTotal, Colors.white),
                  ],
                ),
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              height: 50,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.purpleAccent.withOpacity(0.1)),
                labelColor: Colors.purpleAccent,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(icon: Icon(Icons.add_circle_outline, size: 18), text: "Income"),
                  Tab(icon: Icon(Icons.remove_circle_outline, size: 18), text: "Expense"),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildCategoryList('income'), _buildCategoryList('expense')],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton.extended(
          heroTag: 'categories_fab', // FIX: Added unique heroTag
          onPressed: _addNewCategory,
          backgroundColor: Colors.purpleAccent,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text("New Category", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text("RM ${amount.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
      ],
    );
  }
}
