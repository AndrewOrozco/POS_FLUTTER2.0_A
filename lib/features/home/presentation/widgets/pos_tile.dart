import 'package:flutter/material.dart';

/// Ejemplo de widget reutilizable para tu dashboard (botones tipo tarjeta).
class PosTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const PosTile({super.key, required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [BoxShadow(blurRadius: 8, spreadRadius: 1, offset: Offset(0,2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
