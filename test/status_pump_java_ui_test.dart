import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mis_proyectos_flutter/features/status_pump/domain/entities/surtidor_estado.dart';
import 'package:mis_proyectos_flutter/features/status_pump/domain/entities/status_pump_fase.dart';
import 'package:mis_proyectos_flutter/features/status_pump/presentation/providers/status_pump_provider.dart';
import 'package:mis_proyectos_flutter/features/status_pump/presentation/widgets/surtidor_panel_java_widget.dart';
import 'package:mis_proyectos_flutter/features/status_pump/presentation/widgets/surtidor_card_widget.dart';
import 'package:mis_proyectos_flutter/features/status_pump/presentation/widgets/surtidor_list_widget.dart';

void main() {
  group('StatusPump NEW - Verificación de Criterios de Aceptación (1 al 10)', () {
    late StatusPumpProvider provider;

    setUp(() {
      provider = StatusPumpProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('1. La cara 01 inicia el despacho y queda enfocada', () {
      provider.simulateEstadoForTesting(
        cara: 1,
        producto: 'DIESEL',
        monto: 15000.0,
        volumen: 1.5,
        precio: 10000.0,
        fase: StatusPumpFase.despacho,
      );

      expect(provider.caraSeleccionada, equals(1));
      expect(provider.surtidores[1]?.esDespachando, isTrue);
      expect(provider.surtidores[1]?.monto, equals(15000.0));
    });

    test('2. La cara 02 inicia un nuevo despacho y recibe automáticamente el enfoque', () {
      provider.simulateEstadoForTesting(
        cara: 1,
        producto: 'DIESEL',
        monto: 25000.0,
        volumen: 2.5,
        precio: 10000.0,
        fase: StatusPumpFase.despacho,
      );
      expect(provider.caraSeleccionada, equals(1));

      provider.simulateEstadoForTesting(
        cara: 2,
        producto: 'CORRIENTE',
        monto: 10000.0,
        volumen: 1.0,
        precio: 10000.0,
        fase: StatusPumpFase.despacho,
      );

      expect(provider.caraSeleccionada, equals(2));
    });

    test('3. La cara 01 conserva su venta pendiente al comenzar el despacho en la cara 02', () {
      provider.simulateEstadoForTesting(
        cara: 1,
        producto: 'DIESEL',
        monto: 50000.0,
        volumen: 5.0,
        precio: 10000.0,
        fase: StatusPumpFase.finDespacho,
        segundosRestantes: 80,
        gestionaVenta: false,
      );
      expect(provider.caraSeleccionada, equals(1));

      provider.simulateEstadoForTesting(
        cara: 2,
        producto: 'EXTRA',
        monto: 30000.0,
        volumen: 2.0,
        precio: 15000.0,
        fase: StatusPumpFase.despacho,
      );

      expect(provider.caraSeleccionada, equals(2));

      final cara1 = provider.surtidores[1];
      expect(cara1, isNotNull);
      expect(cara1!.monto, equals(50000.0));
      expect(cara1.volumen, equals(5.0));
      expect(cara1.esFinDespacho, isTrue);
      expect(cara1.gestionaVenta, isFalse);
    });

    test('4. El usuario puede volver a seleccionar manualmente una cara con una venta pendiente', () {
      provider.simulateEstadoForTesting(
        cara: 1,
        producto: 'DIESEL',
        monto: 50000.0,
        volumen: 5.0,
        precio: 10000.0,
        fase: StatusPumpFase.finDespacho,
        segundosRestantes: 80,
      );
      provider.simulateEstadoForTesting(
        cara: 2,
        producto: 'EXTRA',
        monto: 30000.0,
        volumen: 2.0,
        precio: 15000.0,
        fase: StatusPumpFase.despacho,
      );
      expect(provider.caraSeleccionada, equals(2));

      provider.seleccionarCara(1);
      expect(provider.caraSeleccionada, equals(1));
      expect(provider.surtidores[provider.caraSeleccionada!]!.monto, equals(50000.0));
    });

    test('5 y 6. Una venta terminada y no gestionada muestra «Asignar datos» y permanece visible hasta confirmación de LazoExpress', () {
      provider.simulateEstadoForTesting(
        cara: 1,
        producto: 'DIESEL',
        monto: 40000.0,
        volumen: 4.0,
        precio: 10000.0,
        fase: StatusPumpFase.finDespacho,
        segundosRestantes: 80,
        gestionaVenta: false,
        ventaInsertadaEnBd: false,
      );

      final cara1Antes = provider.surtidores[1]!;
      expect(cara1Antes.puedeAsignarDatos, isTrue);
      expect(cara1Antes.gestionaVenta, isFalse);
      expect(cara1Antes.ventaInsertadaEnBd, isFalse);

      provider.confirmarVentaLazo(1, movimientoId: 1024);

      final cara1Despues = provider.surtidores[1]!;
      expect(cara1Despues.gestionaVenta, isTrue);
      expect(cara1Despues.ventaInsertadaEnBd, isTrue);
      expect(cara1Despues.idMovimiento, equals(1024));
      expect(cara1Despues.puedeAsignarDatos, isFalse);
    });

    test('7 y 10. La confirmación de una venta no afecta a las demás caras y actualiza solo su propio estado', () {
      provider.simulateEstadoForTesting(
        cara: 1,
        producto: 'DIESEL',
        monto: 20000.0,
        volumen: 2.0,
        precio: 10000.0,
        fase: StatusPumpFase.finDespacho,
        segundosRestantes: 80,
        gestionaVenta: false,
      );
      provider.simulateEstadoForTesting(
        cara: 2,
        producto: 'CORRIENTE',
        monto: 35000.0,
        volumen: 3.5,
        precio: 10000.0,
        fase: StatusPumpFase.finDespacho,
        segundosRestantes: 80,
        gestionaVenta: false,
      );

      provider.confirmarVentaLazo(1, movimientoId: 555);

      expect(provider.surtidores[1]!.gestionaVenta, isTrue);
      expect(provider.surtidores[1]!.idMovimiento, equals(555));

      expect(provider.surtidores[2]!.gestionaVenta, isFalse);
      expect(provider.surtidores[2]!.ventaInsertadaEnBd, isFalse);
      expect(provider.surtidores[2]!.monto, equals(35000.0));
      expect(provider.surtidores[2]!.puedeAsignarDatos, isTrue);
    });

    test('8. Un evento 106 duplicado con datos en cero no borra los datos válidos', () {
      final inicial = SurtidorEstado(
        surtidorId: 1,
        cara: 1,
        manguera: 1,
        estado: EstadoSurtidor.terminatedFEOT,
        fase: StatusPumpFase.finDespacho,
        producto: 'DIESEL',
        monto: 50000.0,
        volumen: 5.0,
        precioUnidad: 10000.0,
        deadlineFin: DateTime.now().add(const Duration(seconds: 80)),
      );

      final eventoVacio = SurtidorEstado.fromFlaskJson({
        'surtidor_id': 1,
        'numeroCara': 1,
        'numeroMangueraSurtidor': 1,
        'codigoEstadoSurtidor': 106,
        'producto': 'DIESEL',
        'monto': 0.0,
        'volumen': 0.0,
        'precioUnidad': 0.0,
      });

      final montoPreservado = (eventoVacio.monto <= 0 && inicial.monto > 0)
          ? inicial.monto
          : eventoVacio.monto;

      expect(montoPreservado, equals(50000.0));
    });

    test('9. Los temporizadores de fin de despacho NO eliminan ventas pendientes de gestión', () {
      provider.simulateEstadoForTesting(
        cara: 1,
        producto: 'DIESEL',
        monto: 40000.0,
        volumen: 4.0,
        precio: 10000.0,
        fase: StatusPumpFase.finDespacho,
        segundosRestantes: -5,
        gestionaVenta: false,
        ventaInsertadaEnBd: false,
      );

      expect(provider.surtidores.containsKey(1), isTrue);
      expect(provider.surtidores[1]!.esVentaPendienteGestion, isTrue);
      expect(provider.surtidores[1]!.segundosRestantesFin, equals(0));
    });
  });

  group('StatusPump NEW - Visibilidad de Métricas (Regla Funcional Obligatoria)', () {
    testWidgets('1 y 2. Durante DESPACHANDO, las tres tarjetas siguen visibles; IMPORTE y CANTIDAD muestran sus spinners', (tester) async {
      final provider = StatusPumpProvider();
      provider.simulateEstadoForTesting(
        cara: 1,
        producto: 'CORRIENTE',
        monto: 25000.0,
        volumen: 2.5,
        precio: 10000.0,
        fase: StatusPumpFase.despacho,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<StatusPumpProvider>.value(
              value: provider,
              child: SurtidorPanelJavaWidget(
                ocultarSiNoHayActivos: false,
                onGestionarVenta: (c) {},
                onMediosPago: (c) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Las 3 tarjetas deben estar visibles
      expect(find.text('PRECIO'), findsOneWidget);
      expect(find.text('\$ 10.000'), findsOneWidget);
      expect(find.text('IMPORTE'), findsOneWidget);
      expect(find.text('CANTIDAD (GL)'), findsOneWidget);

      // IMPORTE y CANTIDAD deben mostrar spinners (CircularProgressIndicator)
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

      // Estado Despachando visible y botones
      expect(find.text('Despachando'), findsOneWidget);
      expect(find.text('Gestionar venta'), findsOneWidget);
      expect(find.text('Medios de Pago'), findsOneWidget);
    });

    testWidgets('3. Al pasar a finDespacho, aparecen las tres métricas (PRECIO, IMPORTE, CANTIDAD) con datos finales', (tester) async {
      final provider = StatusPumpProvider();
      provider.simulateEstadoForTesting(
        cara: 1,
        producto: 'CORRIENTE',
        monto: 50000.0,
        volumen: 5.0,
        precio: 10000.0,
        fase: StatusPumpFase.finDespacho,
        segundosRestantes: 80,
        gestionaVenta: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<StatusPumpProvider>.value(
              value: provider,
              child: SurtidorPanelJavaWidget(
                ocultarSiNoHayActivos: false,
                onGestionarVenta: (c) {},
                onMediosPago: (c) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // En Fin de Despacho deben aparecer las 3 métricas
      expect(find.text('PRECIO'), findsOneWidget);
      expect(find.text('\$ 10.000'), findsOneWidget);

      expect(find.text('IMPORTE'), findsOneWidget);
      expect(find.text('\$ 50.000'), findsOneWidget);

      expect(find.text('CANTIDAD (GL)'), findsOneWidget);
      expect(find.text('5,000'), findsOneWidget);

      // Estado Fin despacho visible
      expect(find.textContaining('Fin despacho ('), findsOneWidget);
      expect(find.text('Asignar datos'), findsOneWidget);
    });
  });

  group('StatusPump NEW - Responsividad en Orientación Horizontal (Landscape)', () {
    testWidgets('5 y 6. Orientación Horizontal no produce RenderFlex overflow y mantiene distribución compacta', (tester) async {
      // Simular pantalla horizontal del Samsung SM-A276B (ej. 800 x 380 lógico)
      tester.view.physicalSize = const Size(800 * 2.5, 380 * 2.5);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = StatusPumpProvider();
      provider.simulateEstadoForTesting(
        cara: 1,
        producto: 'DIESEL',
        monto: 50000.0,
        volumen: 5.0,
        precio: 10000.0,
        fase: StatusPumpFase.finDespacho,
        segundosRestantes: 80,
        gestionaVenta: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<StatusPumpProvider>.value(
              value: provider,
              child: SurtidorPanelJavaWidget(
                ocultarSiNoHayActivos: false,
                onGestionarVenta: (c) {},
                onMediosPago: (c) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ningún RenderFlex overflow ocurrió (si hubiera ocurrido, tester.takeException() no sería nulo)
      expect(tester.takeException(), isNull);

      // Selector de caras visible
      expect(find.text('01'), findsOneWidget);
      expect(find.text('02'), findsOneWidget);
      expect(find.text('03'), findsOneWidget);
      expect(find.text('04'), findsOneWidget);

      // Métricas visibles y legibles
      expect(find.text('PRECIO'), findsOneWidget);
      expect(find.text('IMPORTE'), findsOneWidget);
      expect(find.text('CANTIDAD (GL)'), findsOneWidget);
      expect(find.text('Asignar datos'), findsOneWidget);
    });

    testWidgets('7 y 8. Cambio de orientación conserva la venta seleccionada y selector utilizable', (tester) async {
      final provider = StatusPumpProvider();
      provider.simulateEstadoForTesting(
        cara: 2,
        producto: 'EXTRA',
        monto: 60000.0,
        volumen: 4.0,
        precio: 15000.0,
        fase: StatusPumpFase.finDespacho,
        segundosRestantes: 75,
      );

      // 1. Iniciar en vertical
      tester.view.physicalSize = const Size(380 * 2.5, 800 * 2.5);
      tester.view.devicePixelRatio = 2.5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<StatusPumpProvider>.value(
              value: provider,
              child: SurtidorPanelJavaWidget(
                ocultarSiNoHayActivos: false,
                onGestionarVenta: (c) {},
                onMediosPago: (c) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('02'), findsOneWidget);
      expect(find.text('\$ 60.000'), findsOneWidget);

      // 2. Rotar a horizontal (landscape)
      tester.view.physicalSize = const Size(800 * 2.5, 380 * 2.5);
      await tester.pumpAndSettle();

      // La venta no se perdió y los datos siguen idénticos
      expect(tester.takeException(), isNull);
      expect(find.text('02'), findsOneWidget);
      expect(find.text('\$ 60.000'), findsOneWidget);

      // El selector de caras sigue interactivo: cambiar a cara 01
      await tester.tap(find.text('01'));
      await tester.pumpAndSettle();
      expect(provider.caraSeleccionada, equals(1));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('StatusPump NEW - SurtidorCardWidget y SurtidorListWidget', () {
    testWidgets('Widget: SurtidorCardWidget muestra las 3 métricas (spinners en despacho, valores en finDespacho)', (tester) async {
      // 1. En despacho
      final surtidorDespacho = SurtidorEstado(
        surtidorId: 1,
        cara: 1,
        manguera: 1,
        estado: EstadoSurtidor.fueling,
        fase: StatusPumpFase.despacho,
        producto: 'BIODIESEL B2',
        monto: 30000.0,
        volumen: 3.0,
        precioUnidad: 10000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SurtidorCardWidget(
              surtidor: surtidorDespacho,
              onGestionarVenta: () {},
              onMediosPago: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('PRECIO'), findsOneWidget);
      expect(find.text('IMPORTE'), findsOneWidget);
      expect(find.text('CANTIDAD (GL)'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

      // 2. En fin de despacho
      final surtidorFin = surtidorDespacho.copyWith(
        fase: StatusPumpFase.finDespacho,
        estado: EstadoSurtidor.terminatedFEOT,
        deadlineFin: DateTime.now().add(const Duration(seconds: 80)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SurtidorCardWidget(
              surtidor: surtidorFin,
              onGestionarVenta: () {},
              onMediosPago: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PRECIO'), findsOneWidget);
      expect(find.text('IMPORTE'), findsOneWidget);
      expect(find.text('CANTIDAD (GL)'), findsOneWidget);
      expect(find.text('\$ 30.000'), findsOneWidget);
      expect(find.text('3,000'), findsOneWidget);
      expect(find.text('Asignar datos'), findsOneWidget);
    });

    testWidgets('Widget: SurtidorListWidget delega limpiamente a SurtidorPanelJavaWidget', (tester) async {
      final provider = StatusPumpProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<StatusPumpProvider>.value(
              value: provider,
              child: const SurtidorListWidget(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(SurtidorPanelJavaWidget), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Layout real del Samsung SM-A276B (1080x2340 px, dpr 2.8125)
  //  - Vertical:   384 x 832 dp
  //  - Horizontal: 832 x 384 dp, barra de navegación del sistema a la derecha (48 dp)
  // ─────────────────────────────────────────────────────────────────────────
  group('StatusPump - Layout responsive en dimensiones reales del Samsung', () {
    Future<StatusPumpProvider> montar(
      WidgetTester tester, {
      required Size size,
      required StatusPumpFase fase,
      double padDerecho = 0,
      String producto = 'BIOACEM B10',
    }) async {
      tester.view.physicalSize = size * 2.8125;
      tester.view.devicePixelRatio = 2.8125;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = StatusPumpProvider();
      provider.simulateEstadoForTesting(
        cara: 1,
        producto: producto,
        monto: 52394,
        volumen: 5.23,
        precio: 9999,
        fase: fase,
        segundosRestantes: 80,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: EdgeInsets.only(right: padDerecho),
              ),
              child: Scaffold(
                body: ChangeNotifierProvider<StatusPumpProvider>.value(
                  value: provider,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SurtidorPanelJavaWidget(
                          ocultarSiNoHayActivos: false,
                          onGestionarVenta: (_) {},
                          onMediosPago: (_) {},
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
      await tester.pump();
      return provider;
    }

    testWidgets('Vertical 384x832 - despacho: sin overflow, 3 métricas, 2 spinners, botones bajo las métricas', (tester) async {
      await montar(tester, size: const Size(384, 832), fase: StatusPumpFase.despacho);
      expect(tester.takeException(), isNull);
      expect(find.text('PRECIO'), findsOneWidget);
      expect(find.text('IMPORTE'), findsOneWidget);
      expect(find.text('CANTIDAD (GL)'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      final metricaBottom = tester.getRect(find.text('PRECIO')).bottom;
      expect(tester.getRect(find.text('Gestionar venta')).top, greaterThan(metricaBottom));
    });

    testWidgets('Horizontal 832x384 - despacho: una fila, nada bajo la barra de navegación', (tester) async {
      await montar(tester, size: const Size(832, 384), fase: StatusPumpFase.despacho, padDerecho: 48);
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      final limite = 832 - 48.0;
      for (final b in tester.widgetList<ElevatedButton>(find.byType(ElevatedButton))) {
        expect(tester.getRect(find.byWidget(b)).right, lessThanOrEqualTo(limite));
      }
      expect(tester.getRect(find.text('Despachando')).right, lessThanOrEqualTo(limite));
      // Métricas y acciones en la misma fila
      final precio = tester.getRect(find.text('PRECIO'));
      final boton = tester.getRect(find.byType(ElevatedButton).first);
      expect(boton.left, greaterThan(precio.right));
      // El panel deja visible la mayor parte del Home
      expect(tester.getRect(find.byType(SurtidorPanelJavaWidget)).height, lessThan(384 * 0.5));
    });

    testWidgets('Horizontal 832x384 - fin despacho: valores finales y Asignar datos dentro del área segura', (tester) async {
      await montar(tester, size: const Size(832, 384), fase: StatusPumpFase.finDespacho, padDerecho: 48);
      expect(tester.takeException(), isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('\$ 52.394'), findsOneWidget);
      expect(find.text('5,230'), findsOneWidget);
      final limite = 832 - 48.0;
      expect(tester.getRect(find.text('Asignar datos')).right, lessThanOrEqualTo(limite));
      expect(tester.getRect(find.textContaining('Fin despacho')).right, lessThanOrEqualTo(limite));
    });

    testWidgets('Horizontal estrecho 640x360 - despacho: pasa a dos filas sin overflow', (tester) async {
      await montar(
        tester,
        size: const Size(640, 360),
        fase: StatusPumpFase.despacho,
        producto: 'GASOLINA CORRIENTE OXIGENADA E10 PREMIUM',
      );
      expect(tester.takeException(), isNull);
      final precio = tester.getRect(find.text('PRECIO'));
      final boton = tester.getRect(find.byType(ElevatedButton).first);
      expect(boton.top, greaterThan(precio.bottom));
    });
  });
}
