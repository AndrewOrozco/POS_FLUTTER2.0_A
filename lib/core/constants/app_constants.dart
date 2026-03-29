class AppConstants {
  // App Info
  static const String appTitle = 'Terpel POS';
  static const String version = '7.0.1';
  static const String stationName = 'EDS LA JUANA';
  static const String userName = 'Diego';
  static const String greeting = 'Hola Diego 👋';

  // Layout Constants
  static const double headerHeight = 56.0;
  static const double sidebarWidth = 70.0;
  static const double rightPanelWidth = 220.0;

  // Animation Constants
  static const Duration animationDuration = Duration(seconds: 3);
  static const Duration animationInterval = Duration(seconds: 4);
  static const Duration timerInterval = Duration(seconds: 1);

  // UI Spacing
  static const double defaultPadding = 20.0;
  static const double smallPadding = 10.0;
  static const double largePadding = 40.0;

  // POS Number
  static const int posNumber = 1;

  // Socket.IO / Flask Configuration
  static const String flaskHost = '127.0.0.1';
  static const int flaskPort = 5000;
  
  // LazoExpress Configuration (Node.js)
  static const String lazoExpressHost = '127.0.0.1';
  static const int lazoExpressPort = 8010; // Puerto de LazoExpress
}
