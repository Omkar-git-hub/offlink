import 'package:flutter/material.dart';

import 'bluetooth/adaptive_ble_discovery.dart';
import 'bluetooth/ble_packet_transport.dart';
import 'bluetooth/ble_peripheral_packet_channel.dart';
import 'bluetooth/flutter_blue_plus_device_connection.dart';
import 'bluetooth/phone_ble_connection.dart';
import 'bluetooth/phone_ble_discovery.dart';
import 'core/identity/node_id_generator.dart';
import 'crypto/identity/identity_key_service.dart';
import 'crypto/session/secure_session_service.dart';
import 'data/database/drift_conversation_repository.dart';
import 'data/database/drift_group_repository.dart';
import 'data/database/drift_message_repository.dart';
import 'data/database/drift_store_and_forward_repository.dart';
import 'data/database/offlink_database.dart';
import 'data/identity/flutter_secure_identity_storage.dart';
import 'data/identity/secure_identity_repository.dart';
import 'data/lifecycle/method_channel_background_service.dart';
import 'data/location/geolocator_location_provider.dart';
import 'domain/battery/adaptive_power_coordinator.dart';
import 'domain/group/group_message_service.dart';
import 'domain/group/group_repository.dart';
import 'domain/identity/identity_initialization_service.dart';
import 'domain/identity/identity_manager.dart';
import 'domain/lifecycle/app_lifecycle_coordinator.dart';
import 'domain/lifecycle/app_lifecycle_manager.dart';
import 'domain/lifecycle/connection_recovery_coordinator.dart';
import 'domain/lifecycle/pending_message_recovery_service.dart';
import 'domain/location/location_service.dart';
import 'domain/mesh/mesh_packet_router.dart';
import 'domain/messaging/direct_message_service.dart';
import 'domain/messaging/message_repository.dart';
import 'domain/messaging/message_service.dart';
import 'domain/queue/store_and_forward_manager.dart';
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

  final meshPacketRouter = MeshPacketRouter(
    transport: packetTransport,
    getLocalNodeId: () =>
        identityManager.currentIdentity?.nodeId ?? 'local-node',
  );

  final database = OfflinkDatabase();
  final messageRepository = DriftMessageRepository(database);
  final conversationRepository = DriftConversationRepository(database);
  final storeAndForwardRepository = DriftStoreAndForwardRepository(database);
  final groupRepository = DriftGroupRepository(database);

  final storeAndForwardManager = StoreAndForwardManager(
    repository: storeAndForwardRepository,
    transport: packetTransport,
    routingTable: meshPacketRouter.routingTable,
    getLocalNodeId: () =>
        identityManager.currentIdentity?.nodeId ?? 'local-node',
    getConnectedPeerIds: () => packetTransport.connectedPeerIds,
  );
  meshPacketRouter.storeAndForwardManager = storeAndForwardManager;

  final secureSessionService = SecureSessionService(
    identityKeyService: identityKeyService,
    getLocalNodeId: () =>
        identityManager.currentIdentity?.nodeId ?? 'local-node',
  );

  final messageService = DirectMessageService(
    packetTransport: meshPacketRouter,
    identityManager: identityManager,
    messageRepository: messageRepository,
    conversationRepository: conversationRepository,
    secureSessionService: secureSessionService,
  );

  final groupMessageService = GroupMessageService(
    packetTransport: meshPacketRouter,
    identityManager: identityManager,
    groupRepository: groupRepository,
    messageRepository: messageRepository,
    conversationRepository: conversationRepository,
    secureSessionService: secureSessionService,
  );

  final locationProvider = const GeolocatorLocationProvider();
  final locationService = LocationService(
    locationProvider: locationProvider,
    packetTransport: meshPacketRouter,
    identityManager: identityManager,
    secureSessionService: secureSessionService,
    messageRepository: messageRepository,
    conversationRepository: conversationRepository,
    groupRepository: groupRepository,
  );

  final backgroundService = MethodChannelBackgroundService();
  final lifecycleManager = AppLifecycleManager();
  final phoneDiscovery = PhoneBleDiscovery();
  final adaptiveDiscovery = AdaptiveBleDiscovery(underlying: phoneDiscovery);

  final powerCoordinator = AdaptivePowerCoordinator(
    lifecycleManager: lifecycleManager,
    discovery: adaptiveDiscovery,
    getConnectedPeerIds: () => packetTransport.connectedPeerIds,
    hasActiveLiveLocation: () => locationService.hasActiveLiveSessions,
  );

  final connectionRecovery = ConnectionRecoveryCoordinator(
    connection: bleConnection,
  );
  final pendingMessageRecovery = PendingMessageRecoveryService(
    messageService: messageService,
    messageRepository: messageRepository,
  );
  final lifecycleCoordinator = AppLifecycleCoordinator(
    lifecycleManager: lifecycleManager,
    backgroundService: backgroundService,
    connectionRecovery: connectionRecovery,
    pendingMessageRecovery: pendingMessageRecovery,
    storeAndForwardManager: storeAndForwardManager,
    discovery: adaptiveDiscovery,
    powerCoordinator: powerCoordinator,
  );
  lifecycleCoordinator.initialize();

  runApp(
    OfflinkApp(
      identityManager: identityManager,
      hasIdentity: identity != null,
      bleConnection: bleConnection,
      packetTransport: packetTransport,
      meshRouter: meshPacketRouter,
      discovery: adaptiveDiscovery,
      phoneDiscovery: phoneDiscovery,
      powerCoordinator: powerCoordinator,
      lifecycleCoordinator: lifecycleCoordinator,
      connectionRecovery: connectionRecovery,
      messageService: messageService,
      messageRepository: messageRepository,
      groupMessageService: groupMessageService,
      groupRepository: groupRepository,
      locationService: locationService,
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
    this.meshRouter,
    this.discovery,
    this.phoneDiscovery,
    this.powerCoordinator,
    this.lifecycleCoordinator,
    this.connectionRecovery,
    required this.messageService,
    this.messageRepository,
    this.groupMessageService,
    this.groupRepository,
    this.locationService,
    this.database,
  });

  final IdentityManager identityManager;
  final bool hasIdentity;
  final PhoneBleConnection bleConnection;
  final BlePacketTransport packetTransport;
  final MeshPacketRouter? meshRouter;
  final AdaptiveBleDiscovery? discovery;
  final PhoneBleDiscovery? phoneDiscovery;
  final AdaptivePowerCoordinator? powerCoordinator;
  final AppLifecycleCoordinator? lifecycleCoordinator;
  final ConnectionRecoveryCoordinator? connectionRecovery;
  final MessageService messageService;
  final MessageRepository? messageRepository;
  final GroupMessageService? groupMessageService;
  final GroupRepository? groupRepository;
  final LocationService? locationService;
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
    widget.lifecycleCoordinator?.dispose();
    widget.powerCoordinator?.dispose();
    widget.discovery?.dispose();
    widget.phoneDiscovery?.dispose();
    widget.locationService?.dispose();
    widget.groupMessageService?.dispose();
    widget.messageService.dispose();
    widget.meshRouter?.dispose();
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
              meshRouter: widget.meshRouter,
              discovery: widget.discovery,
              powerCoordinator: widget.powerCoordinator,
              lifecycleCoordinator: widget.lifecycleCoordinator,
              connectionRecovery: widget.connectionRecovery,
              identityManager: widget.identityManager,
              messageService: widget.messageService,
              messageRepository: widget.messageRepository,
              groupMessageService: widget.groupMessageService,
              groupRepository: widget.groupRepository,
              locationService: widget.locationService,
            )
          : OnboardingPage(onContinue: _createIdentity),
    );
  }
}
