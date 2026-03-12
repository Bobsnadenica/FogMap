class BackendConfig {
  static const String awsRegion = 'eu-west-2';

  static const String cognitoUserPoolId = 'eu-west-2_ORdu8sqG1';
  static const String cognitoUserPoolClientId = '579drfqkb4uueotbod29qq7cs7';

  static const String appSyncApiId = 'xuhhcjmpkremxcv2vrzpgxfrlm';
  static const String appSyncGraphqlUrl =
      'https://3focrrhosbd7dkxtkthji467tu.appsync-api.eu-west-2.amazonaws.com/graphql';

  static const String cloudFrontApprovedDomain =
      'd2op1xtsiy6g50.cloudfront.net';
  static const String cloudFrontSharedTilesDomain = '';

  static const String defaultWorldId = 'global';

  static const String pendingLandmarkBucketName =
      'world-of-fog-prod-010419877195-eu-west-2-pending';
  static const String approvedLandmarkBucketName =
      'world-of-fog-prod-010419877195-eu-west-2-approved';

  static const String userDiscoveriesTableName =
      'world-of-fog-prod-user-discoveries';
  static const String sharedCellsTableName =
      'world-of-fog-prod-shared-cells';
  static const String playerPresenceTableName =
      'world-of-fog-prod-player-presence';
  static const String landmarksTableName =
      'world-of-fog-prod-landmarks';

  static const List<String> cognitoGroupNames = <String>[
    'admin',
    'moderator',
    'user',
  ];
}
