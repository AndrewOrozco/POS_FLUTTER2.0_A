import 'package:flutter/material.dart';

/// Teclado táctil personalizado estilo Terpel
/// 
/// Diseño flotante compacto con paleta Terpel:
/// - Gris oscuro de fondo (descansa la vista)
/// - Rojo Terpel solo en acentos sutiles
/// - Naranja para Aceptar, Verde para Borrar
/// - Teclas claras sobre fondo oscuro
class TecladoTactil extends StatelessWidget {
  final TextEditingController controller;
  final bool soloNumeros;
  final VoidCallback? onAceptar;
  final double? height;
  /// Color tema opcional. Si se pasa, el teclado usa tonos de ese color.
  /// Ejemplo: Color(0xFFBA0C2F) para rojo Terpel en Iniciar Turno.
  final Color? colorTema;

  // Colores default (gris oscuro)
  static const _defaultBg = Color(0xFF2D2D2D);
  static const _defaultKey = Color(0xFF404040);
  static const _defaultKeyAlt = Color(0xFF4A4A4A);
  static const _defaultBorder = Color(0xFF505050);

  // Colores fijos
  static const _textColor = Color(0xFFF5F5F5);
  static const _accentOrange = Color(0xFFFF8C00);
  static const _accentGreen = Color(0xFF43A047);

  // Colores derivados del tema
  Color get _bgColor => colorTema != null
      ? HSLColor.fromColor(colorTema!).withLightness(0.18).withSaturation(0.6).toColor()
      : _defaultBg;
  Color get _keyColor => colorTema != null
      ? HSLColor.fromColor(colorTema!).withLightness(0.25).withSaturation(0.5).toColor()
      : _defaultKey;
  Color get _keyColorAlt => colorTema != null
      ? HSLColor.fromColor(colorTema!).withLightness(0.30).withSaturation(0.5).toColor()
      : _defaultKeyAlt;
  Color get _borderColor => colorTema != null
      ? HSLColor.fromColor(colorTema!).withLightness(0.35).withSaturation(0.4).toColor()
      : _defaultBorder;
  Color get _spaceColor => colorTema != null
      ? HSLColor.fromColor(colorTema!).withLightness(0.32).withSaturation(0.45).toColor()
      : const Color(0xFF505050);

  const TecladoTactil({
    super.key,
    required this.controller,
    this.soloNumeros = false,
    this.onAceptar,
    this.height,
    this.colorTema,
  });

  @override
  Widget build(BuildContext context) {
    if (soloNumeros) {
      return _buildTecladoNumerico();
    }
    return _buildTecladoAlfanumerico();
  }

  Widget _buildTecladoAlfanumerico() {
    return Container(
      height: height ?? 260,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border.all(color: _borderColor.withAlpha(60), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          // Indicador de arrastre sutil
          Container(
            width: 40,
            height: 3,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Fila 1: Q W E R T Y U I O P 1 2 3
          Expanded(child: _buildFila(['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '1', '2', '3'])),
          const SizedBox(height: 4),
          // Fila 2: A S D F G H J K L Ñ 4 5 6
          Expanded(child: _buildFila(['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ñ', '4', '5', '6'])),
          const SizedBox(height: 4),
          // Fila 3: Z X C V B N M , . : 7 8 9
          Expanded(child: _buildFila(['Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.', ':', '7', '8', '9'])),
          const SizedBox(height: 4),
          // Fila 4: - @ [ESPACIO] _ % B 0 A
          Expanded(child: _buildFilaEspecial()),
        ],
      ),
    );
  }

  Widget _buildTecladoNumerico() {
    return Container(
      height: height ?? 260,
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border.all(color: _borderColor.withAlpha(60), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Indicador de arrastre
          Container(
            width: 40,
            height: 3,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Fila 1: 1 2 3
          Expanded(child: _buildFilaNumerica(['1', '2', '3'])),
          const SizedBox(height: 5),
          // Fila 2: 4 5 6
          Expanded(child: _buildFilaNumerica(['4', '5', '6'])),
          const SizedBox(height: 5),
          // Fila 3: 7 8 9
          Expanded(child: _buildFilaNumerica(['7', '8', '9'])),
          const SizedBox(height: 5),
          // Fila 4: B 0 A
          Expanded(child: _buildFilaAcciones()),
        ],
      ),
    );
  }

  Widget _buildFila(List<String> teclas) {
    return Row(
      children: teclas.map((tecla) {
        // Los números al final tienen un tono ligeramente distinto
        final esNumero = int.tryParse(tecla) != null;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _TeclaTactil(
              texto: tecla,
              onTap: () => _agregarCaracter(tecla),
              bgColor: esNumero ? _keyColorAlt : _keyColor,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFilaNumerica(List<String> teclas) {
    return Row(
      children: teclas.map((tecla) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _TeclaTactil(
              texto: tecla,
              onTap: () => _agregarCaracter(tecla),
              bgColor: _keyColor,
              grande: true,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFilaEspecial() {
    return Row(
      children: [
        // -
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _TeclaTactil(
              texto: '-',
              onTap: () => _agregarCaracter('-'),
              bgColor: _keyColor,
            ),
          ),
        ),
        // @
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _TeclaTactil(
              texto: '@',
              onTap: () => _agregarCaracter('@'),
              bgColor: _keyColor,
            ),
          ),
        ),
        // ESPACIO (más ancho)
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _TeclaTactil(
              texto: 'ESPACIO',
              onTap: () => _agregarCaracter(' '),
              bgColor: _spaceColor,
            ),
          ),
        ),
        // _
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _TeclaTactil(
              texto: '_',
              onTap: () => _agregarCaracter('_'),
              bgColor: _keyColor,
            ),
          ),
        ),
        // %
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _TeclaTactil(
              texto: '%',
              onTap: () => _agregarCaracter('%'),
              bgColor: _keyColor,
            ),
          ),
        ),
        // B (Borrar) - Verde
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _TeclaTactil(
              texto: '⌫',
              subtexto: 'BORRAR',
              bgColor: _accentGreen,
              onTap: _borrarCaracter,
            ),
          ),
        ),
        // 0
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _TeclaTactil(
              texto: '0',
              onTap: () => _agregarCaracter('0'),
              bgColor: _keyColorAlt,
            ),
          ),
        ),
        // A (Aceptar) - Naranja
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _TeclaTactil(
              texto: '✓',
              subtexto: 'OK',
              bgColor: _accentOrange,
              onTap: onAceptar,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilaAcciones() {
    return Row(
      children: [
        // B (Borrar) - Verde
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _TeclaTactil(
              texto: '⌫',
              subtexto: 'BORRAR',
              bgColor: _accentGreen,
              onTap: _borrarCaracter,
              grande: true,
            ),
          ),
        ),
        // 0
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _TeclaTactil(
              texto: '0',
              onTap: () => _agregarCaracter('0'),
              bgColor: _keyColor,
              grande: true,
            ),
          ),
        ),
        // A (Aceptar) - Naranja
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _TeclaTactil(
              texto: '✓',
              subtexto: 'ACEPTAR',
              bgColor: _accentOrange,
              onTap: onAceptar,
              grande: true,
            ),
          ),
        ),
      ],
    );
  }

  void _agregarCaracter(String caracter) {
    final text = controller.text;
    final selection = controller.selection;
    
    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, caracter);
      controller.text = newText;
      controller.selection = TextSelection.collapsed(offset: selection.start + caracter.length);
    } else {
      controller.text = text + caracter;
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
    }
  }

  void _borrarCaracter() {
    final text = controller.text;
    final selection = controller.selection;
    
    if (text.isEmpty) return;
    
    if (selection.isValid && selection.start > 0) {
      if (selection.start == selection.end) {
        // No hay selección, borrar caracter anterior
        final newText = text.replaceRange(selection.start - 1, selection.start, '');
        controller.text = newText;
        controller.selection = TextSelection.collapsed(offset: selection.start - 1);
      } else {
        // Hay selección, borrar selección
        final newText = text.replaceRange(selection.start, selection.end, '');
        controller.text = newText;
        controller.selection = TextSelection.collapsed(offset: selection.start);
      }
    } else if (text.isNotEmpty) {
      controller.text = text.substring(0, text.length - 1);
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
    }
  }
}

class _TeclaTactil extends StatelessWidget {
  final String texto;
  final String? subtexto;
  final Color bgColor;
  final VoidCallback? onTap;
  final bool grande;

  const _TeclaTactil({
    required this.texto,
    this.subtexto,
    required this.bgColor,
    this.onTap,
    this.grande = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.white.withAlpha(30),
        highlightColor: Colors.white.withAlpha(15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withAlpha(20),
              width: 0.5,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      texto,
                      style: TextStyle(
                        color: TecladoTactil._textColor,
                        fontSize: grande ? 28 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtexto != null)
                      Text(
                        subtexto!,
                        style: TextStyle(
                          color: TecladoTactil._textColor.withAlpha(180),
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de texto con teclado táctil integrado
class CampoConTeclado extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final bool soloNumeros;
  final String? hint;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const CampoConTeclado({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.soloNumeros = false,
    this.hint,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<CampoConTeclado> createState() => _CampoConTecladoState();
}

class _CampoConTecladoState extends State<CampoConTeclado> {
  bool _mostrarTeclado = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && widget.enabled) {
        setState(() => _mostrarTeclado = true);
      }
    });
    
    widget.controller.addListener(() {
      widget.onChanged?.call(widget.controller.text);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          readOnly: true, // Evitar teclado del sistema
          style: const TextStyle(fontSize: 18), // Texto más grande
          onTap: widget.enabled ? () {
            setState(() => _mostrarTeclado = !_mostrarTeclado);
          } : null,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: widget.icon != null 
                ? Icon(widget.icon, size: 28) 
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _mostrarTeclado ? Icons.keyboard_hide : Icons.keyboard,
                size: 28,
              ),
              onPressed: widget.enabled ? () {
                setState(() => _mostrarTeclado = !_mostrarTeclado);
              } : null,
            ),
          ),
        ),
        
        if (_mostrarTeclado) ...[
          const SizedBox(height: 12),
          TecladoTactil(
            controller: widget.controller,
            soloNumeros: widget.soloNumeros,
            height: widget.soloNumeros ? 280 : 280,
            onAceptar: () {
              setState(() => _mostrarTeclado = false);
              _focusNode.unfocus();
            },
          ),
        ],
      ],
    );
  }
}

/// Campo de placa con formato XXX-000 o ABC123
class CampoPlaca extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;

  const CampoPlaca({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  @override
  State<CampoPlaca> createState() => _CampoPlacaState();
}

class _CampoPlacaState extends State<CampoPlaca> {
  bool _mostrarTeclado = false;

  @override
  void initState() {
    super.initState();
    // Escuchar cambios del controller para actualizar la UI
    widget.controller.addListener(_onTextChanged);
  }
  
  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }
  
  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PLACA:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        
        // Campo visual de placa
        GestureDetector(
          onTap: widget.enabled ? () {
            setState(() => _mostrarTeclado = !_mostrarTeclado);
          } : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _mostrarTeclado ? const Color(0xFFFF8C00) : Colors.grey.shade300,
                width: _mostrarTeclado ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_car, color: Colors.grey.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.controller.text.isEmpty 
                        ? 'Toque para ingresar placa' 
                        : widget.controller.text.toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: widget.controller.text.isEmpty 
                          ? Colors.grey 
                          : Colors.black,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                Icon(
                  _mostrarTeclado ? Icons.keyboard_hide : Icons.keyboard,
                  color: Colors.grey,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
        
        if (_mostrarTeclado) ...[
          const SizedBox(height: 12),
          TecladoTactil(
            controller: widget.controller,
            soloNumeros: false,
            height: 280,
            onAceptar: () {
              setState(() => _mostrarTeclado = false);
            },
          ),
        ],
      ],
    );
  }
}
