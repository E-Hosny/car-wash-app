import 'package:upgrader/upgrader.dart';

class ForceUpdateMessages extends UpgraderMessages {
  ForceUpdateMessages({String? code}) : super(code: code ?? 'en');

  String get body => 'A new version of the app is available. Please update to continue.';

  String get buttonTextIgnore => '';

  String get buttonTextLater => '';

  String get buttonTextUpdate => 'Update Now';

  String get prompt => '';

  String get title => 'Update Available';
}

