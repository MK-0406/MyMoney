import 'package:flutter/material.dart';
import 'records.dart';
import 'accounts.dart';
import 'category.dart';
import 'super_category.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int currentPageIndex = 0;

  // Pages are now preserved in memory using IndexedStack
  final List<Widget> _pages = [
    const RecordsPage(),
    const AccountsPage(),
    const CategoriesPage(),
    const SuperCategoriesPage(),
  ];

  void _onDestinationSelected(int index) {
    if (index == currentPageIndex) return;

    HapticFeedback.lightImpact();

    setState(() {
      currentPageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade50, Colors.purple.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            // FIX: IndexedStack prevents layout errors during transitions 
            // and keeps your scroll position and data loaded on each tab.
            child: IndexedStack(
              index: currentPageIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildFloatingNavigationBar(),
    );
  }

  Widget _buildFloatingNavigationBar() {
    return SafeArea(
      maintainBottomViewPadding: true,
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: Colors.purpleAccent.withOpacity(0.12),
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.purpleAccent,
                    );
                  }
                  return const TextStyle(fontSize: 11, color: Colors.grey);
                }),
              ),
              child: NavigationBar(
                elevation: 0,
                height: 72,
                selectedIndex: currentPageIndex,
                onDestinationSelected: _onDestinationSelected,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: const [
                  NavigationDestination(
                    selectedIcon: Icon(Icons.home_rounded, color: Colors.purpleAccent),
                    icon: Icon(Icons.home_outlined, color: Colors.grey),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: Colors.purpleAccent),
                    icon: Icon(Icons.account_balance_wallet_outlined, color: Colors.grey),
                    label: 'Accounts',
                  ),
                  NavigationDestination(
                    selectedIcon: Icon(Icons.category_rounded, color: Colors.purpleAccent),
                    icon: Icon(Icons.category_outlined, color: Colors.grey),
                    label: 'Categories',
                  ),
                  NavigationDestination(
                    selectedIcon: Icon(Icons.auto_awesome_motion_rounded, color: Colors.purpleAccent),
                    icon: Icon(Icons.auto_awesome_motion_outlined, color: Colors.grey),
                    label: 'Groups',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
