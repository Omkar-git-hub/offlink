abstract interface class BackgroundServiceContract {
  Future<bool> startService({String? title, String? message});
  Future<bool> stopService();
  Future<bool> isServiceRunning();
}
