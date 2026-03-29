import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';

class CenterContentWidget extends StatelessWidget {
  const CenterContentWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.largePadding,
        vertical: AppConstants.defaultPadding,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo social
          Image.asset(
            'assets/icons/terpel/Terpel_logosimbolo_rojo.png',
            width: MediaQuery.of(context).size.width < 600 ? 280 : 420,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
