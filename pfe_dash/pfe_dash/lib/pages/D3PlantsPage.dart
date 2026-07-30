import 'package:flutter/material.dart';

class D3PlantsPage extends StatelessWidget {
  const D3PlantsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_florist, size: 100, color: Colors.blue),
          SizedBox(height: 20),
          Text(
            '3D Plants',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Explore our collection of 3D plants',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
