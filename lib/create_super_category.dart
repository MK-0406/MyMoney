import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreateSuperCategoryPage extends StatefulWidget {
  final String? groupId;
  final Map<String, dynamic>? initialData;

  const CreateSuperCategoryPage({super.key, this.groupId, this.initialData});

  @override
  State<CreateSuperCategoryPage> createState() => _CreateSuperCategoryPageState();
}

class _CreateSuperCategoryPageState extends State<CreateSuperCategoryPage> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  List<String> selectedCatIds = [];
  String? imageBase64;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.groupId != null && widget.initialData != null) {
      _nameController.text = widget.initialData!['name'] ?? '';
      selectedCatIds = List<String>.from(widget.initialData!['subCategoryIds'] ?? []);
      imageBase64 = widget.initialData!['imageBase64'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 100,
      maxHeight: 100,
      imageQuality: 50,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        imageBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _saveGroup() async {
    if (user == null) return;
    
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a group name")),
      );
      return;
    }

    if (selectedCatIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one category")),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final groupData = {
        'name': _nameController.text.trim(),
        'subCategoryIds': selectedCatIds,
        'imageBase64': imageBase64,
        'deleted': false,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.groupId != null) {
        await FirebaseFirestore.instance
            .collection('super_categories')
            .doc(user!.uid)
            .collection('super_category')
            .doc(widget.groupId)
            .update(groupData);
      } else {
        groupData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('super_categories')
            .doc(user!.uid)
            .collection('super_category')
            .add(groupData);
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(widget.groupId == null ? "Create Group" : "Edit Group", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isSaving)
            const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else
            IconButton(
              icon: const Icon(Icons.check_rounded, color: Colors.deepPurple, size: 28),
              onPressed: _saveGroup,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image and Name Section
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.grey.shade100,
                      backgroundImage: imageBase64 != null 
                        ? MemoryImage(base64Decode(imageBase64!)) 
                        : null,
                      child: imageBase64 == null 
                        ? const Icon(Icons.add_a_photo, size: 30, color: Colors.grey) 
                        : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("GROUP NAME", style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                  ),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: "e.g. Shopping or Food",
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(24, 32, 24, 12),
              child: Text("SELECT CATEGORIES", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('categories')
                  .doc(user!.uid)
                  .collection('category')
                  .where('deleted', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                }
                
                final categories = snapshot.data?.docs ?? [];
                if (categories.isEmpty) {
                  return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No categories found", style: TextStyle(color: Colors.grey))));
                }

                final sortedCategories = categories.toList();
                sortedCategories.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  
                  final typeA = (dataA['type'] ?? '').toString();
                  final typeB = (dataB['type'] ?? '').toString();
                  final typeCompare = typeA.compareTo(typeB);
                  if (typeCompare != 0) return typeCompare;

                  final nameA = (dataA['name'] ?? '').toString();
                  final nameB = (dataB['name'] ?? '').toString();
                  return nameA.toLowerCase().compareTo(nameB.toLowerCase());
                });

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedCategories.length,
                  itemBuilder: (context, index) {
                    final cat = sortedCategories[index];
                    final data = cat.data() as Map<String, dynamic>;
                    final isSelected = selectedCatIds.contains(cat.id);
                    final isExpense = data['type'] == 'expense';

                    bool showHeader = index == 0 || (sortedCategories[index - 1].data() as Map<String, dynamic>)['type'] != data['type'];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                            child: Text(
                              isExpense ? "EXPENSES" : "INCOME",
                              style: TextStyle(color: isExpense ? Colors.red.shade300 : Colors.green.shade300, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5)],
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            activeColor: Colors.deepPurple,
                            checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            secondary: Icon(
                              isExpense ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
                              color: isExpense ? Colors.red.shade300 : Colors.green.shade300,
                              size: 20,
                            ),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  selectedCatIds.add(cat.id);
                                } else {
                                  selectedCatIds.remove(cat.id);
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}
