abstract interface class Transport {
  Future<void> start();

  Future<void> stop();

  Future<void> connect(String peerId);

  Future<void> disconnect(String peerId);

  Future<void> send({required String peerId, required List<int> data});

  Stream<List<int>> get incomingPackets;
}
