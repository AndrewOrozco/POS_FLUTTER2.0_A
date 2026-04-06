import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

class CarAnimationWidget extends StatefulWidget {
  const CarAnimationWidget({super.key});

  @override
  State<CarAnimationWidget> createState() => _CarAnimationWidgetState();
}

class _CarAnimationWidgetState extends State<CarAnimationWidget>
    with TickerProviderStateMixin {
  late Timer _carAnimationTimer;
  late AnimationController _animationController;
  late Animation<double> _fuelAnimation;
  bool _showCarAnimation = false;

  @override
  void initState() {
    super.initState();

    // Configurar animación del carro tanqueando
    _animationController = AnimationController(
      duration: AppConstants.animationDuration,
      vsync: this,
    );

    _fuelAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Animación del carro cada 4 segundos
    _carAnimationTimer = Timer.periodic(AppConstants.animationInterval, (
      timer,
    ) {
      setState(() {
        _showCarAnimation = true;
      });
      _animationController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _showCarAnimation = false;
            });
            _animationController.reset();
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _carAnimationTimer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildCarAnimation() {
    return ListenableBuilder(
      listenable: _fuelAnimation,
      builder: (context, child) {
        // Calcular posición del carro (se mueve de izquierda a derecha)
        double carPosition = _fuelAnimation.value * 80;
        bool isRefueling = _fuelAnimation.value > 0.6;

        return Container(
          padding: const EdgeInsets.all(AppConstants.smallPadding),
          child: Stack(
            children: [
              // Estación de servicio (imagen real, fija en el lado derecho)
              Positioned(
                right: 0,
                top: 5,
                child: Image.asset(
                  'assets/images/station.png',
                  width: 100,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),

              // Carro en movimiento (imagen Terpel) - va hacia la estación
              Positioned(
                right: 100 - carPosition,
                top: 50,
                child: Image.asset(
                  'assets/icons/terpel/car_terpel.png',
                  width: 70,
                  height: 35,
                  fit: BoxFit.contain,
                ),
              ),

              // Efectos de combustible (gotitas animadas)
              if (isRefueling)
                Positioned(
                  right: 12 - carPosition,
                  top: 40,
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.terpeRed.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showCarAnimation) return const SizedBox.shrink();

    return Positioned(
      bottom: 26,
      right: 290,
      child: Container(
        width: 320,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.transparent, width: 0),
        ),
        child: _buildCarAnimation(),
      ),
    );
  }
}