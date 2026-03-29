import 'package:flutter/material.dart';
import '../../domain/entities/surtidor_estado.dart';
import 'surtidor_card_widget.dart';

/// Widget que anima la entrada de un surtidor con un carrito llegando a la EDS
class AnimatedSurtidorCard extends StatefulWidget {
  final SurtidorEstado surtidor;
  final VoidCallback? onGestionarVenta;
  final VoidCallback? onMediosPago;
  final int index;
  final bool ventaGestionada;

  const AnimatedSurtidorCard({
    super.key,
    required this.surtidor,
    required this.index,
    this.onGestionarVenta,
    this.onMediosPago,
    this.ventaGestionada = false,
  });

  @override
  State<AnimatedSurtidorCard> createState() => _AnimatedSurtidorCardState();
}

class _AnimatedSurtidorCardState extends State<AnimatedSurtidorCard>
    with TickerProviderStateMixin {
  late AnimationController _carController;
  late AnimationController _cardController;
  late Animation<double> _carSlideAnimation;
  late Animation<double> _carFadeAnimation;
  late Animation<double> _cardScaleAnimation;
  late Animation<double> _cardFadeAnimation;

  bool _showCard = false;

  @override
  void initState() {
    super.initState();

    // Animación del carrito (1 segundo)
    _carController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Animación del card (0.5 segundos)
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // El carrito se desliza desde la derecha hacia la izquierda
    _carSlideAnimation = Tween<double>(
      begin: 300.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _carController,
      curve: Curves.easeOutCubic,
    ));

    // El carrito se desvanece al llegar
    _carFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _carController,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    ));

    // El card aparece con scale
    _cardScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.elasticOut,
    ));

    // El card aparece con fade
    _cardFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeIn,
    ));

    // Escuchar cuando el carrito termina para mostrar el card
    _carController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showCard = true;
        });
        _cardController.forward();
      }
    });

    // Iniciar la animación con un delay basado en el índice
    Future.delayed(Duration(milliseconds: widget.index * 150), () {
      if (mounted) {
        _carController.forward();
      }
    });
  }

  @override
  void dispose() {
    _carController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 336, // Ancho del card + margen (320 + 16)
      height: 360,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Carrito animado
          if (!_showCard)
            ListenableBuilder(
              listenable: _carController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_carSlideAnimation.value, 0),
                  child: Opacity(
                    opacity: _carFadeAnimation.value,
                    child: _buildCar(),
                  ),
                );
              },
            ),

          // Card del surtidor
          if (_showCard)
            ListenableBuilder(
              listenable: _cardController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _cardScaleAnimation.value,
                  child: Opacity(
                    opacity: _cardFadeAnimation.value,
                    child: SurtidorCardWidget(
                      surtidor: widget.surtidor,
                      onGestionarVenta: widget.onGestionarVenta,
                      ventaGestionada: widget.ventaGestionada,
                      onMediosPago: widget.onMediosPago,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Carrito emoji o imagen
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Carrito con ruedas animadas
              _buildAnimatedCar(),
              const SizedBox(height: 8),
              const Text(
                '🚗 Llegando...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedCar() {
    return SizedBox(
      width: 140,
      height: 80,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(-1.0, 1.0),
        child: Image.asset(
          'assets/icons/terpel/car_terpel.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
