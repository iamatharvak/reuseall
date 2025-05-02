import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/map_screen.dart';
import 'services/location_service.dart';


void main() {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Run the app
  runApp(const ReuseAllRiderApp());
}

class ReuseAllRiderApp extends StatelessWidget {
  const ReuseAllRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReuseAll Rider',
      theme: ThemeData(
        primarySwatch: Colors.green,
        // Use Material 3 design
        useMaterial3: true,
        // Define app color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
      ),
      // Use a dark theme if system is set to dark mode
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      ),
      // Use the system theme mode (light/dark)
      themeMode: ThemeMode.system,
      // Define home screen
      home: MultiProvider(
        providers: [
          // Provide LocationService to the widget tree
          Provider<LocationService>(
            create: (_) => LocationService(),
            dispose: (_, service) => service.dispose(),
          ),
        ],
        child: const MapScreen(),
      ),
    );
  }
}