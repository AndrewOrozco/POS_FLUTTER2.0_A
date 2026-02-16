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
            'assets/images/terpel_logo_og.png',
            width: MediaQuery.of(context).size.width < 600 ? 250 : 500,
            height: MediaQuery.of(context).size.width < 600 ? 120 : 150,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
