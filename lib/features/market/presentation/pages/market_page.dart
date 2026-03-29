import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/api_consultas_service.dart';
import 'market_checkout_page.dart';
import 'market_historial_page.dart';

/// Página principal del módulo Market (kiosco/KCO).
/// Layout de 2 paneles: Catálogo (izquierda) + Carrito (derecha).
/// Misma estructura que CanastillaPage pero con productos tipoStore='K'.
class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  final ApiConsultasService _api = ApiConsultasService();
  final TextEditingController _buscarCtrl = TextEditingController();
  Timer? _debounce;

  // Color scheme Market — Paleta Terpel
  static const Color _primaryColor = Color(0xFFFF0B18);   // Rojo Terpel
  static const Color _primaryDark = Color(0xFFB20000);    // Rojo medio
  static const Color _primaryLight = Color(0xFFF3FFFF);   // Cielo Terpel
  static const Color _accentColor = Color(0xFF7C0000);    // Rojo oscuro

  // Productos
  List<ProductoCanastilla> _productos = [];
  int _totalProductos = 0;
  int _page = 1;
  final int _pageSize = 50;
  bool _cargando = false;

  // Categorías
  List<CategoriaCanastilla> _categorias = [];
  int? _categoriaSeleccionada;

  // Carrito
  final List<ItemCarrito> _carrito = [];

  // Toast overlay
  OverlayEntry? _toastEntry;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
    _cargarProductos();
  }

  @override
  void dispose() {
    _toastEntry?.remove();
    _buscarCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    final cats = await _api.obtenerCategoriasMarket();
    if (mounted) setState(() => _categorias = cats);
  }

  Future<void> _cargarProductos({bool reset = true}) async {
    if (_cargando) return;
    setState(() => _cargando = true);

    if (reset) _page = 1;

    final data = await _api.obtenerProductosMarket(
      page: _page,
      pageSize: _pageSize,
      buscar: _buscarCtrl.text.trim().isEmpty ? null : _buscarCtrl.text.trim(),
      categoriaId: _categoriaSeleccionada,
    );

    if (!mounted) return;

    final list = (data['productos'] as List?)
            ?.map((e) => ProductoCanastilla.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    setState(() {
      _totalProductos = parseInt(data['total']);
      if (reset) {
        _productos = list;
      } else {
        _productos.addAll(list);
      }
      _cargando = false;
    });
  }

  void _onBuscar(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _cargarProductos();
    });
  }

  void _seleccionarCategoria(int? catId) {
    setState(() {
      _categoriaSeleccionada = catId == _categoriaSeleccionada ? null : catId;
    });
    _cargarProductos();
  }

  void _agregarAlCarrito(ProductoCanastilla producto) {
    setState(() {
      final idx = _carrito.indexWhere((i) => i.producto.id == producto.id);
      if (idx >= 0) {
        _carrito[idx].cantidad++;
      } else {
        _carrito.add(ItemCarrito(producto: producto));
      }
    });
    _mostrarToastAgregado(producto.descripcion);
  }

  void _mostrarToastAgregado(String nombre) {
    _toastEntry?.remove();
    _toastEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        top: 58,
        left: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 200),
            builder: (_, val, child) => Opacity(opacity: val, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26, blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(
                      '+ $nombre',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_toastEntry!);
    Future.delayed(const Duration(milliseconds: 800), () {
      _toastEntry?.remove();
      _toastEntry = null;
    });
  }

  void _cambiarCantidad(int idx, int delta) {
    setState(() {
      _carrito[idx].cantidad += delta;
      if (_carrito[idx].cantidad <= 0) {
        _carrito.removeAt(idx);
      }
    });
  }

  void _eliminarItem(int idx) {
    setState(() => _carrito.removeAt(idx));
  }

  // Subtotal = base sin impuestos (como Java: precio - IVA incluido)
  double get _subtotalCarrito =>
      _carrito.fold(0.0, (s, i) => s + (i.subtotal - i.impuestoTotal));

  double get _impuestoCarrito =>
      _carrito.fold(0.0, (s, i) => s + i.impuestoTotal);

  // Total = precio completo (subtotal incluye el impuesto)
  double get _totalCarrito =>
      _carrito.fold(0.0, (s, i) => s + i.subtotal);

  int get _totalItemsCarrito =>
      _carrito.fold(0, (s, i) => s + i.cantidad);

  void _irACheckout() {
    if (_carrito.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarketCheckoutPage(
          carrito: List.from(_carrito),
          onVentaExitosa: () {
            setState(() => _carrito.clear());
            _cargarProductos();
          },
        ),
      ),
    );
  }

  void _irAHistorial() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MarketHistorialPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.storefront, size: 28),
            const SizedBox(width: 10),
            const Text('Market',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            const Spacer(),
            TextButton.icon(
              onPressed: _irAHistorial,
              icon: const Icon(Icons.history, color: Colors.white),
              label: const Text('HISTORIAL',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        elevation: 2,
      ),
      body: Row(
        children: [
          // ==================== PANEL IZQUIERDO: CATÁLOGO ====================
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _buildSearchBar(),
                _buildCategoriaChips(),
                Expanded(child: _buildProductGrid()),
              ],
            ),
          ),
          // ==================== PANEL DERECHO: CARRITO ====================
          SizedBox(
            width: 380,
            child: _buildCartPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _buscarCtrl,
              onChanged: _onBuscar,
              decoration: InputDecoration(
                hintText: 'Buscar producto por nombre o PLU...',
                prefixIcon: Icon(Icons.search, color: _primaryColor),
                suffixIcon: _buscarCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _buscarCtrl.clear();
                          _cargarProductos();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$_totalProductos productos',
              style: TextStyle(
                  color: _accentColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriaChips() {
    return Container(
      height: 50,
      color: Colors.white,
      padding: const EdgeInsets.only(left: 12, bottom: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todos'),
              selected: _categoriaSeleccionada == null,
              selectedColor: _primaryColor,
              labelStyle: TextStyle(
                color: _categoriaSeleccionada == null
                    ? Colors.white
                    : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              onSelected: (_) => _seleccionarCategoria(null),
            ),
          ),
          ..._categorias.map((cat) {
            final sel = _categoriaSeleccionada == cat.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${cat.descripcion} (${cat.totalProductos})'),
                selected: sel,
                selectedColor: _primaryColor,
                labelStyle: TextStyle(
                  color: sel ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                onSelected: (_) => _seleccionarCategoria(cat.id),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_cargando && _productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            const SizedBox(height: 16),
            const Text('Cargando productos...'),
          ],
        ),
      );
    }

    if (_productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No se encontraron productos',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scroll) {
        if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200 &&
            !_cargando &&
            _productos.length < _totalProductos) {
          _page++;
          _cargarProductos(reset: false);
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.78,
        ),
        itemCount: _productos.length + (_cargando ? 1 : 0),
        itemBuilder: (ctx, idx) {
          if (idx >= _productos.length) {
            return Center(
                child: CircularProgressIndicator(color: _primaryColor));
          }
          return _buildProductCard(_productos[idx]);
        },
      ),
    );
  }

  Widget _buildProductCard(ProductoCanastilla producto) {
    final sinStock = producto.saldo <= 0;
    return GestureDetector(
      onTap: sinStock ? null : () => _agregarAlCarrito(producto),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: sinStock
              ? Border.all(color: Colors.red.shade100, width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ícono de producto
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _primaryLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          producto.esCompuesto
                              ? Icons.fastfood_rounded
                              : Icons.storefront_rounded,
                          size: 36,
                          color: sinStock
                              ? Colors.grey.shade400
                              : _primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Nombre
                  Expanded(
                    flex: 2,
                    child: Text(
                      producto.descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sinStock ? Colors.grey : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // PLU
                  Text(
                    'PLU: ${producto.plu}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  // Precio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${producto.precio.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: sinStock
                              ? Colors.grey
                              : _accentColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: sinStock
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sinStock
                              ? 'Sin stock'
                              : 'Stock: ${producto.saldo.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: sinStock
                                ? Colors.red.shade600
                                : Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Badge categoría
            if (producto.categoriaDescripcion != 'OTROS')
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    producto.categoriaDescripcion,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: _accentColor),
                  ),
                ),
              ),
            // Overlay sin stock
            if (sinStock)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            // Botón agregar
            if (!sinStock)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 10,
            offset: const Offset(-3, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header carrito
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _primaryDark],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'CARRITO',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_totalItemsCarrito items',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          // Lista de items
          Expanded(
            child: _carrito.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'Carrito vacío',
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toca un producto para agregar',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: _carrito.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) => _buildCartItem(idx),
                  ),
          ),
          // Resumen + botón pagar
          _buildCartSummary(),
        ],
      ),
    );
  }

  Widget _buildCartItem(int idx) {
    final item = _carrito[idx];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.producto.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${item.producto.precio.toStringAsFixed(0)} c/u',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _cambiarCantidad(idx, -1),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(7),
                        bottomLeft: Radius.circular(7),
                      ),
                    ),
                    child: const Icon(Icons.remove, size: 18),
                  ),
                ),
                Container(
                  width: 36, height: 32,
                  alignment: Alignment.center,
                  child: Text(
                    '${item.cantidad}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                InkWell(
                  onTap: () => _cambiarCantidad(idx, 1),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(7),
                        bottomRight: Radius.circular(7),
                      ),
                    ),
                    child: Icon(Icons.add,
                        size: 18, color: _accentColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              '\$${item.subtotal.toStringAsFixed(0)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _accentColor),
            ),
          ),
          InkWell(
            onTap: () => _eliminarItem(idx),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.delete_outline,
                  size: 20, color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primaryLight,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal:', style: TextStyle(fontSize: 14)),
              Text('\$${_subtotalCarrito.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Impuestos:', style: TextStyle(fontSize: 14)),
              Text('\$${_impuestoCarrito.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 14)),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(
                '\$${_totalCarrito.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _accentColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _carrito.isEmpty ? null : _irACheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: const Icon(Icons.payment, size: 24),
              label: const Text('PAGAR',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
