import 'package:flutter/material.dart';

import 'bluetooth/ble_packet_transport.dart';
import 'bluetooth/ble_peripheral_packet_channel.dart';
import 'bluetooth/flutter_blue_plus_device_connection.dart';
import 'bluetooth/phone_ble_connection.dart';
import 'core/identity/node_id_generator.dart';
import 'crypto/identity/identity_key_service.dart';
import 'data/database/drift_conversation_repository.dart';
import 'data/database/drift_message_repository.dart';
import 'data/database/offlink_database.dart';
import 'data/identity/flutter_secure_identity_storage.dart';
import 'data/identity/secure_identity_repository.dart';
import 'domain/identity/identity_initialization_service.dart';
import 'domain/identity/identity_manager.dart';
import 'domain/messaging/direct_message_service.dart';
import 'domain/messaging/message_repository.dart';
import 'domain/messaging/message_service.dart';
import 'features/home_page.dart';
import 'features/onboarding/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final identityRepository = SecureIdentityRepository(
    storage: FlutterSecureIdentityStorage(),
  );

  final identityKeyService = IdentityKeyService();

  final identityInitializationService = IdentityInitializationService(
    nodeIdGenerator: NodeIdGenerator(),
    keyService: identityKeyService,
  );

  final identityManager = IdentityManager(
    repository: identityRepository,
    keyService: identityKeyService,
    initializationService: identityInitializationService,
  );

  final identity = await identityManager.loadAndValidateIdentity();

  final bleDeviceConnection = const FlutterBluePlusDeviceConnection();

  final bleConnection = PhoneBleConnection(
    deviceConnection: bleDeviceConnection,
  );

  final peripheralChannel = FlutterBlePeripheralPacketChannel();

  final packetTransport = BlePacketTransport(
    deviceConnection: bleDeviceConnection,
    peripheralChannel: peripheralChannel,
  );

  final database = OfflinkDatabase();
  final messageRepository = DriftMessageRepository(database);
  final conversationRepository = DriftConversationRepository(database);

  final messageService = DirectMessageService(
    packetTransport: packetTransport,
    identityManager: identityManager,
    messageRepository: messageRepository,
    conversationRepository: conversationRepository,
  );

  runApp(
    OfflinkApp(
      identityManager: identityManager,
      hasIdentity: identity != null,
      bleConnection: bleConnection,
      packetTransport: packetTransport,
      messageService: messageService,
      messageRepository: messageRepository,
      database: database,
    ),
  );
}

class OfflinkApp extends StatefulWidget {
  const OfflinkApp({
    super.key,
    required this.identityManager,
    required this.hasIdentity,
    required this.bleConnection,
    required this.packetTransport,
    required this.messageService,
    this.messageRepository,
    this.database,
  });

  final IdentityManager identityManager;
  final bool hasIdentity;
  final PhoneBleConnection bleConnection;
  final BlePacketTransport packetTransport;
  final MessageService messageService;
  final MessageRepository? messageRepository;
  final OfflinkDatabase? database;

  @override
  State<OfflinkApp> createState() => _OfflinkAppState();
}

class _OfflinkAppState extends State<OfflinkApp> {
  late bool _hasIdentity;

  @override
  void initState() {
    super.initState();
    _hasIdentity = widget.hasIdentity;
  }

  Future<void> _createIdentity(String username) async {
    await widget.identityManager.createIdentity(username: username);

    if (!mounted) {
      return;
    }

    setState(() {
      _hasIdentity = true;
    });
  }

  @override
  void dispose() {
    widget.messageService.dispose();
    widget.packetTransport.dispose();
    widget.bleConnection.dispose();
    widget.database?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offlink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: _hasIdentity
          ? HomePage(
              bleConnection: widget.bleConnection,
              packetTransport: widget.packetTransport,
              identityManager: widget.identityManager,
              messageService: widget.messageService,
              messageRepository: widget.messageRepository,
            )
          : OnboardingPage(onContinue: _createIdentity),
    );
  }
}
