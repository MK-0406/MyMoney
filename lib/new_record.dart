import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'home.dart';

class CreateRecordPage extends StatefulWidget {
  final String? recordId;
  final Map<String, dynamic>? initialData;

  const CreateRecordPage({super.key, this.recordId, this.initialData});

  @override
  State<CreateRecordPage> createState() => _CreateRecordPageState();
}

class _CreateRecordPageState extends State<CreateRecordPage> {
  late String recordType;
  late String accountSelected;
  late String accountIdSelected;
  late String accountImageBase64;
  late String categorySelected;
  late String categoryIdSelected;
  late String categoryImageBase64;

  String toAccountSelected = '';
  String toAccountIdSelected = '';
  String toAccountImageBase64 = '';

  late String formattedDate;
  late DateTime dateSelected;
  late double amount;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      recordType = widget.initialData!['type'] ?? 'income';
      accountSelected = widget.initialData!['account'] ?? '';
      accountIdSelected = widget.initialData!['accountId'] ?? '';
      accountImageBase64 = widget.initialData!['accountImage'] ?? '';
      categorySelected = widget.initialData!['category'] ?? '';
      categoryIdSelected = widget.initialData!['categoryId'] ?? '';
      categoryImageBase64 = widget.initialData!['categoryImage'] ?? '';

      toAccountSelected = widget.initialData!['toAccount'] ?? '';
      toAccountIdSelected = widget.initialData!['toAccountId'] ?? '';
      toAccountImageBase64 = widget.initialData!['toAccountImage'] ?? '';

      dateSelected = (widget.initialData!['date'] as Timestamp).toDate();
      formattedDate = widget.initialData!['dateStr'] ??
          DateFormat('EEE, dd MMM yyyy').format(dateSelected);
      amount = (widget.initialData!['amount'] ?? 0).toDouble();
      _amountController.text = amount > 0 ? amount.toString() : '';
    } else {
      recordType = 'income';
      accountSelected = '';
      accountIdSelected = '';
      accountImageBase64 = '';
      categorySelected = '';
      categoryIdSelected = '';
      categoryImageBase64 = '';
      dateSelected = DateTime.now();
      formattedDate = DateFormat('EEE, dd MMM yyyy').format(dateSelected);
      amount = 0;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Widget _buildAccountCard(String id, Map<String, dynamic> account,
      {bool isToAccount = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: account['imageBase64'] != null
            ? CircleAvatar(
                backgroundImage:
                    MemoryImage(base64Decode(account['imageBase64'])))
            : CircleAvatar(
                backgroundColor: Colors.deepPurple.shade50,
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.deepPurple)),
        title: Text(account['name'] ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: () {
          setState(() {
            if (isToAccount) {
              toAccountSelected = account['name'] ?? 'Unknown';
              toAccountIdSelected = id;
              toAccountImageBase64 = account['imageBase64'] ?? '';
            } else {
              accountSelected = account['name'] ?? 'Unknown';
              accountIdSelected = id;
              accountImageBase64 = account['imageBase64'] ?? '';
            }
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildCategoryCard(String id, Map<String, dynamic> category) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: category['imageBase64'] != null
            ? CircleAvatar(
                backgroundImage:
                    MemoryImage(base64Decode(category['imageBase64'])))
            : CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.category, color: Colors.blue)),
        title: Text(category['name'] ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: () {
          setState(() {
            categorySelected = category['name'] ?? 'Unknown';
            categoryIdSelected = id;
            categoryImageBase64 = category['imageBase64'];
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildList(bool isAccount, {bool isToAccount = false}) {
    final user = FirebaseAuth.instance.currentUser;
    final collection = isAccount ? 'accounts' : 'categories';
    final subCollection = isAccount ? 'account' : 'category';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .doc(user!.uid)
          .collection(subCollection)
          .where('deleted', isEqualTo: false)
          .orderBy("name")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs.where((doc) {
          if (isAccount) return true;
          final data = doc.data() as Map<String, dynamic>;
          return data['type'] == recordType;
        }).toList();

        if (docs.isEmpty)
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text("No items found",
                      style: TextStyle(color: Colors.grey))));
        return ListView.builder(
          shrinkWrap: true,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            return isAccount
                ? _buildAccountCard(id, data, isToAccount: isToAccount)
                : _buildCategoryCard(id, data);
          },
        );
      },
    );
  }

  Future<void> _addNewItem(bool isAccount) async {
    XFile? pickedImage;
    _nameController.clear();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(isAccount ? "New Account" : "New Category",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final image = await _picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 100,
                          maxHeight: 100,
                          imageQuality: 50);
                      if (image != null)
                        setDialogState(() => pickedImage = image);
                    },
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.grey.shade100,
                      backgroundImage: pickedImage != null
                          ? FileImage(File(pickedImage!.path))
                          : null,
                      child: pickedImage == null
                          ? const Icon(Icons.add_a_photo,
                              size: 30, color: Colors.grey)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: "Enter Name",
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      )),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel",
                      style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null || _nameController.text.isEmpty) return;
                  String? base64;
                  if (pickedImage != null)
                    base64 = base64Encode(await pickedImage!.readAsBytes());
                  final coll = isAccount ? 'accounts' : 'categories';
                  final subColl = isAccount ? 'account' : 'category';

                  Map<String, dynamic> data = {
                    'name': _nameController.text,
                    'imageBase64': base64,
                    'createdAt': FieldValue.serverTimestamp(),
                    'deleted': false
                  };

                  if (isAccount) {
                    data['balance'] = 0.0;
                    data['totalIncome'] = 0.0;
                    data['totalExpense'] = 0.0;
                  } else {
                    data['type'] = recordType;
                  }

                  await FirebaseFirestore.instance
                      .collection(coll)
                      .doc(user.uid)
                      .collection(subColl)
                      .add(data);
                  Navigator.pop(context);
                },
                child: const Text("Create"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
        title: Text(widget.recordId == null ? "New Record" : "Edit Record",
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.deepPurple, size: 28),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null || accountIdSelected.isEmpty) return;
              if (recordType == 'transfer' && toAccountIdSelected.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Select destination account")));
                return;
              }
              if (recordType == 'transfer' &&
                  accountIdSelected == toAccountIdSelected) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Cannot transfer to the same account")));
                return;
              }

              final batch = FirebaseFirestore.instance.batch();
              DocumentReference recordRef;

              if (widget.recordId != null) {
                recordRef = FirebaseFirestore.instance
                    .collection('records')
                    .doc(user.uid)
                    .collection('year')
                    .doc(dateSelected.year.toString())
                    .collection('month')
                    .doc(dateSelected.month.toString())
                    .collection('record')
                    .doc(widget.recordId);

                // REVERSE OLD AGGREGATION
                final oldAmount = (widget.initialData!['amount'] ?? 0) as num;
                final oldType = widget.initialData!['type'];
                final oldAccountId = widget.initialData!['accountId'];
                final oldToAccountId = widget.initialData!['toAccountId'];

                if (oldAccountId != null) {
                  final oldAccRef = FirebaseFirestore.instance
                      .collection('accounts')
                      .doc(user.uid)
                      .collection('account')
                      .doc(oldAccountId);
                  double revChange = oldType == 'income'
                      ? -oldAmount.toDouble()
                      : oldAmount.toDouble();
                  batch.update(oldAccRef, {
                    'balance': FieldValue.increment(revChange),
                    'totalIncome': oldType == 'income'
                        ? FieldValue.increment(-oldAmount.toDouble())
                        : FieldValue.increment(0),
                    'totalExpense': oldType == 'expense'
                        ? FieldValue.increment(-oldAmount.toDouble())
                        : FieldValue.increment(0)
                  });
                }
                if (oldType == 'transfer' && oldToAccountId != null) {
                  final oldToAccRef = FirebaseFirestore.instance
                      .collection('accounts')
                      .doc(user.uid)
                      .collection('account')
                      .doc(oldToAccountId);
                  batch.update(oldToAccRef,
                      {'balance': FieldValue.increment(-oldAmount.toDouble())});
                }
              } else {
                recordRef = FirebaseFirestore.instance
                    .collection('records')
                    .doc(user.uid)
                    .collection('year')
                    .doc(dateSelected.year.toString())
                    .collection('month')
                    .doc(dateSelected.month.toString())
                    .collection('record')
                    .doc();
              }

              // SAVE RECORD
              Map<String, dynamic> recordData = {
                'userId': user.uid,
                'type': recordType,
                'account': accountSelected,
                'accountId': accountIdSelected,
                'accountImage': accountImageBase64,
                'category':
                    recordType == 'transfer' ? "Transfer" : categorySelected,
                'categoryId': categoryIdSelected,
                'amount': amount,
                'date': dateSelected,
                'dateStr': formattedDate,
                'day': dateSelected.day,
                'deleted': false,
              };
              if (recordType == 'transfer') {
                recordData['toAccount'] = toAccountSelected;
                recordData['toAccountId'] = toAccountIdSelected;
                recordData['toAccountImage'] = toAccountImageBase64;
              }
              batch.set(recordRef, recordData);

              // APPLY NEW AGGREGATION
              final accRef = FirebaseFirestore.instance
                  .collection('accounts')
                  .doc(user.uid)
                  .collection('account')
                  .doc(accountIdSelected);
              if (recordType == 'transfer') {
                batch
                    .update(accRef, {'balance': FieldValue.increment(-amount)});
                final toAccRef = FirebaseFirestore.instance
                    .collection('accounts')
                    .doc(user.uid)
                    .collection('account')
                    .doc(toAccountIdSelected);
                batch.update(
                    toAccRef, {'balance': FieldValue.increment(amount)});
              } else {
                double change = recordType == 'income' ? amount : -amount;
                batch.update(accRef, {
                  'balance': FieldValue.increment(change),
                  'totalIncome': recordType == 'income'
                      ? FieldValue.increment(amount)
                      : FieldValue.increment(0),
                  'totalExpense': recordType == 'expense'
                      ? FieldValue.increment(amount)
                      : FieldValue.increment(0)
                });
              }

              await batch.commit();
              if (mounted)
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const MainDashboard()));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("AMOUNT",
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1)),
                      TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (val) => setState(
                              () => amount = double.tryParse(val) ?? 0),
                          style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: recordType == 'expense'
                                  ? Colors.red
                                  : (recordType == 'income'
                                      ? Colors.green
                                      : Colors.blue)),
                          decoration: const InputDecoration(
                              prefixText: "RM ",
                              border: InputBorder.none,
                              hintText: "0.00")),
                    ])),
            const SizedBox(height: 20),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12)),
                    child: IntrinsicHeight(
                        child: Row(children: [
                      _typeBtn("Income", 'income'),
                      _typeBtn("Expense", 'expense'),
                      _typeBtn("Transfer", 'transfer')
                    ])))),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                _buildSelector(
                    recordType == 'transfer' ? "From Account" : "Account",
                    accountSelected,
                    accountImageBase64,
                    Icons.account_balance_wallet, () {
                  showModalBottomSheet(
                      context: context,
                      backgroundColor: const Color(0xFFF8F9FE),
                      shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(24))),
                      builder: (context) =>
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text("Select Source Account",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18))),
                            Flexible(
                                child: _buildList(true, isToAccount: false)),
                            Padding(
                                padding: const EdgeInsets.all(16),
                                child: TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _addNewItem(true);
                                    },
                                    child: const Text("Add New Account",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))))
                          ]));
                }),
                const SizedBox(height: 16),
                _buildSelector(
                    recordType == 'transfer' ? "To Account" : "Category",
                    recordType == 'transfer'
                        ? toAccountSelected
                        : categorySelected,
                    recordType == 'transfer'
                        ? toAccountImageBase64
                        : categoryImageBase64,
                    recordType == 'transfer'
                        ? Icons.account_balance_wallet_outlined
                        : Icons.category, () {
                  if (recordType == 'transfer') {
                    showModalBottomSheet(
                        context: context,
                        backgroundColor: const Color(0xFFF8F9FE),
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24))),
                        builder: (context) =>
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text("Select Destination Account",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18))),
                              Flexible(
                                  child: _buildList(true, isToAccount: true)),
                              Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _addNewItem(true);
                                      },
                                      child: const Text("Add New Account",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))))
                            ]));
                  } else {
                    showModalBottomSheet(
                        context: context,
                        backgroundColor: const Color(0xFFF8F9FE),
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24))),
                        builder: (context) =>
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text("Select Category",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18))),
                              Flexible(child: _buildList(false)),
                              Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _addNewItem(false);
                                      },
                                      child: const Text("Add New Category",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))))
                            ]));
                  }
                }),
              ]),
            ),
            const SizedBox(height: 30),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: dateSelected,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now());
                      if (picked != null)
                        setState(() {
                          dateSelected = picked;
                          formattedDate =
                              DateFormat('EEE, dd MMM yyyy').format(picked);
                        });
                    },
                    child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200)),
                        child: Row(children: [
                          const Icon(Icons.calendar_month,
                              color: Colors.deepPurple),
                          const SizedBox(width: 12),
                          Text(formattedDate,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16)),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios,
                              size: 14, color: Colors.grey)
                        ])))),
          ],
        ),
      ),
    );
  }

  Widget _typeBtn(String label, String type) {
    bool isSelected = recordType == type;
    return Expanded(
        child: GestureDetector(
            onTap: () => setState(() => recordType = type),
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ]
                        : []),
                child: Center(
                    child: Text(label,
                        style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.deepPurple
                                : Colors.grey.shade600))))));
  }

  Widget _buildSelector(
      String label, String value, String? imageBase64, IconData icon, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 1)),
      const SizedBox(height: 8),
      InkWell(
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Row(children: [
                imageBase64 != ''
                    ? CircleAvatar(backgroundImage: MemoryImage(base64Decode(imageBase64!)))
                    : Icon(icon, size: 20, color: Colors.deepPurple),
                const SizedBox(width: 20),
                Expanded(
                    child: Text(value.isEmpty ? "Select" : value,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: value.isEmpty ? Colors.grey : Colors.black,
                            fontSize: 15),
                        overflow: TextOverflow.ellipsis))
              ]))),
    ]);
  }
}
