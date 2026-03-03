import 'package:flutter/material.dart';

class CategoryUtils {
  static IconData icon(String category) {
    switch (category) {
      case 'Bills, Utilities & Taxes':
        return Icons.receipt_long;
      case 'Education':
        return Icons.school;
      case 'Entertainment':
        return Icons.movie;
      case 'Food & Drinks':
        return Icons.restaurant;
      case 'Groceries':
        return Icons.shopping_cart;
      case 'Health & Fitness':
        return Icons.fitness_center;
      case 'Housing':
        return Icons.home;
      case 'Others':
        return Icons.more_horiz;
      case 'Transport':
        return Icons.directions_bus;
      case 'Travel':
        return Icons.flight;
      default:
        return Icons.attach_money;
    }
  }
}
