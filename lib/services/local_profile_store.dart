import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';
import '../data/models/player_profile.dart';

class LocalProfileStore {
  Future<File> _profileFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/${AppConstants.profileFileName}');
  }

  Future<PlayerProfile> load() async {
    final file = await _profileFile();
    if (!await file.exists()) {
      final empty = PlayerProfile.createEmpty();
      await save(empty);
      return empty;
    }

    final raw = await file.readAsString();
    final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
    return PlayerProfile.fromJson(jsonMap);
  }

  Future<void> save(PlayerProfile profile) async {
    final file = await _profileFile();
    final encoder = const JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(profile.toJson()));
  }
}