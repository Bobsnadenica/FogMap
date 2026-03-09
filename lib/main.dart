import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/app_controller.dart';
import 'services/local_profile_store.dart';
import 'services/location_service.dart';
import 'services/share_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = AppController(
    localProfileStore: LocalProfileStore(),
    locationService: LocationService(),
    shareService: ShareService(),
  );

  await controller.init();

  runApp(FogFrontierApp(controller: controller));
}