import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import '../data/models/player_profile.dart';

class ShareService {
  Future<void> shareProfile(PlayerProfile profile) async {
    final jsonText = const JsonEncoder.withIndent('  ').convert(profile.toJson());

    await SharePlus.instance.share(
      ShareParams(
        text: 'My FogFrontier world progress export',
        files: [
          XFile.fromData(
            utf8.encode(jsonText),
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: const ['fogfrontier_profile.json'],
        subject: 'FogFrontier profile export',
        title: 'Share your world map',
      ),
    );
  }
}
