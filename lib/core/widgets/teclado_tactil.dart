import 'package:flutter/material.dart';

/// Teclado táctil personalizado estilo Terpel
/// 
/// Soporta modo alfanumérico y numérico
class TecladoTactil extends StatelessWidget {
  final TextEditingController controller;
  final bool soloNumeros;
  final VoidCallback? onAceptar;
  final double? height;

  const TecladoTactil({
    super.key,
    required this.controller,
    this.soloNumeros = false,
    this.onAceptar,
    this.height,
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
      height: height ?? 280, // Más grande para pantallas táctiles
      decoration: BoxDecoration(
        color: const Color(0xFFBA0C2F),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Fila 1: Q W E R T Y U I O P 1 2 3
          Expanded(child: _buildFila(['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '1', '2', '3'])),
          const SizedBox(height: 6),
          // Fila 2: A S D F G H J K L Ñ 4 5 6
          Expanded(child: _buildFila(['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ñ', '4', '5', '6'])),
          const SizedBox(height: 6),
          // Fila 3: Z X C V B N M , . : 7 8 9
          Expanded(child: _buildFila(['Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.', ':', '7', '8', '9'])),
          const SizedBox(height: 6),
          // Fila 4: - @ [ESPACIO] _ % B 0 A
          Expanded(child: _buildFilaEspecial()),
        ],
      ),
    );
  }

  Widget _buildTecladoNumerico() {
    return Container(
      height: height ?? 280, // Más grande para pantallas táctiles
      decoration: BoxDecoration(
        color: const Color(0xFFBA0C2F),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Fila 1: 1 2 3
          Expanded(child: _buildFilaNumerica(['1', '2', '3'])),
          const SizedBox(height: 8),
          // Fila 2: 4 5 6
          Expanded(child: _buildFilaNumerica(['4', '5', '6'])),
          const SizedBox(height: 8),
          // Fila 3: 7 8 9
          Expanded(child: _buildFilaNumerica(['7', '8', '9'])),
          const SizedBox(height: 8),
          // Fila 4: B 0 A
          Expanded(child: _buildFilaAcciones()),
        ],
      ),
    );
  }

  Widget _buildFila(List<String> teclas) {
    return Row(
      children: teclas.map((tecla) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _TeclaTactil(
              texto: tecla,
              onTap: () => _agregarCaracter(tecla),
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
            padding: const EdgeInsets.all(4),
            child: _TeclaTactil(
              texto: tecla,
              onTap: () => _agregarCaracter(tecla),
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
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _TeclaTactil(
              texto: '-',
              onTap: () => _agregarCaracter('-'),
            ),
          ),
        ),
        // @
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _TeclaTactil(
              texto: '@',
              onTap: () => _agregarCaracter('@'),
            ),
          ),
        ),
        // ESPACIO (más ancho)
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _TeclaTactil(
              texto: 'ESPACIO',
              onTap: () => _agregarCaracter(' '),
            ),
          ),
        ),
        // _
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _TeclaTactil(
              texto: '_',
              onTap: () => _agregarCaracter('_'),
            ),
          ),
        ),
        // %
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _TeclaTactil(
              texto: '%',
              onTap: () => _agregarCaracter('%'),
            ),
          ),
        ),
        // B (Borrar) - Verde
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _TeclaTactil(
              texto: 'B',
              subtexto: 'BORRAR',
              color: Colors.green,
              onTap: _borrarCaracter,
            ),
          ),
        ),
        // 0
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _TeclaTactil(
              texto: '0',
              onTap: () => _agregarCaracter('0'),
            ),
          ),
        ),
        // A (Aceptar) - Naranja
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _TeclaTactil(
              texto: 'A',
              subtexto: 'ACEPTAR',
              color: Colors.orange,
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
            padding: const EdgeInsets.all(4),
            child: _TeclaTactil(
              texto: 'B',
              subtexto: 'BORRAR',
              color: Colors.green,
              onTap: _borrarCaracter,
              grande: true,
            ),
          ),
        ),
        // 0
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: _TeclaTactil(
              texto: '0',
              onTap: () => _agregarCaracter('0'),
              grande: true,
            ),
          ),
        ),
        // A (Aceptar) - Naranja
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: _TeclaTactil(
              texto: 'A',
              subtexto: 'ACEPTAR',
              color: Colors.orange,
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
  final Color? color;
  final VoidCallback? onTap;
  final bool grande;

  const _TeclaTactil({
    required this.texto,
    this.subtexto,
    this.color,
    this.onTap,
    this.grande = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withAlpha(80)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      texto,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: grande ? 32 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtexto != null)
                      Text(
                        subtexto!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
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
            height: widget.soloNumeros ? 320 : 320, // Más grande para táctil
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
        const Text(
          'PLACA:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFBA0C2F),
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
                color: _mostrarTeclado ? const Color(0xFFBA0C2F) : Colors.grey.shade300,
                width: _mostrarTeclado ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_car, color: Color(0xFFBA0C2F), size: 28),
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
            height: 320, // Más grande para táctil
            onAceptar: () {
              setState(() => _mostrarTeclado = false);
            },
          ),
        ],
      ],
    );
  }
}
