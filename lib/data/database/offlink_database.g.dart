// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offlink_database.dart';

// ignore_for_file: type=lint
class $ConversationsTableTable extends ConversationsTable
    with TableInfo<$ConversationsTableTable, ConversationsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerNodeIdMeta = const VerificationMeta(
    'peerNodeId',
  );
  @override
  late final GeneratedColumn<String> peerNodeId = GeneratedColumn<String>(
    'peer_node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerDisplayNameMeta = const VerificationMeta(
    'peerDisplayName',
  );
  @override
  late final GeneratedColumn<String> peerDisplayName = GeneratedColumn<String>(
    'peer_display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastMessageMeta = const VerificationMeta(
    'lastMessage',
  );
  @override
  late final GeneratedColumn<String> lastMessage = GeneratedColumn<String>(
    'last_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    peerNodeId,
    peerDisplayName,
    lastMessage,
    unreadCount,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('peer_node_id')) {
      context.handle(
        _peerNodeIdMeta,
        peerNodeId.isAcceptableOrUnknown(
          data['peer_node_id']!,
          _peerNodeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_peerNodeIdMeta);
    }
    if (data.containsKey('peer_display_name')) {
      context.handle(
        _peerDisplayNameMeta,
        peerDisplayName.isAcceptableOrUnknown(
          data['peer_display_name']!,
          _peerDisplayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_peerDisplayNameMeta);
    }
    if (data.containsKey('last_message')) {
      context.handle(
        _lastMessageMeta,
        lastMessage.isAcceptableOrUnknown(
          data['last_message']!,
          _lastMessageMeta,
        ),
      );
    }
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      peerNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_node_id'],
      )!,
      peerDisplayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_display_name'],
      )!,
      lastMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message'],
      ),
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ConversationsTableTable createAlias(String alias) {
    return $ConversationsTableTable(attachedDatabase, alias);
  }
}

class ConversationsTableData extends DataClass
    implements Insertable<ConversationsTableData> {
  final String id;
  final String peerNodeId;
  final String peerDisplayName;
  final String? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;
  const ConversationsTableData({
    required this.id,
    required this.peerNodeId,
    required this.peerDisplayName,
    this.lastMessage,
    required this.unreadCount,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['peer_node_id'] = Variable<String>(peerNodeId);
    map['peer_display_name'] = Variable<String>(peerDisplayName);
    if (!nullToAbsent || lastMessage != null) {
      map['last_message'] = Variable<String>(lastMessage);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationsTableCompanion toCompanion(bool nullToAbsent) {
    return ConversationsTableCompanion(
      id: Value(id),
      peerNodeId: Value(peerNodeId),
      peerDisplayName: Value(peerDisplayName),
      lastMessage: lastMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessage),
      unreadCount: Value(unreadCount),
      updatedAt: Value(updatedAt),
    );
  }

  factory ConversationsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationsTableData(
      id: serializer.fromJson<String>(json['id']),
      peerNodeId: serializer.fromJson<String>(json['peerNodeId']),
      peerDisplayName: serializer.fromJson<String>(json['peerDisplayName']),
      lastMessage: serializer.fromJson<String?>(json['lastMessage']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'peerNodeId': serializer.toJson<String>(peerNodeId),
      'peerDisplayName': serializer.toJson<String>(peerDisplayName),
      'lastMessage': serializer.toJson<String?>(lastMessage),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ConversationsTableData copyWith({
    String? id,
    String? peerNodeId,
    String? peerDisplayName,
    Value<String?> lastMessage = const Value.absent(),
    int? unreadCount,
    DateTime? updatedAt,
  }) => ConversationsTableData(
    id: id ?? this.id,
    peerNodeId: peerNodeId ?? this.peerNodeId,
    peerDisplayName: peerDisplayName ?? this.peerDisplayName,
    lastMessage: lastMessage.present ? lastMessage.value : this.lastMessage,
    unreadCount: unreadCount ?? this.unreadCount,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ConversationsTableData copyWithCompanion(ConversationsTableCompanion data) {
    return ConversationsTableData(
      id: data.id.present ? data.id.value : this.id,
      peerNodeId: data.peerNodeId.present
          ? data.peerNodeId.value
          : this.peerNodeId,
      peerDisplayName: data.peerDisplayName.present
          ? data.peerDisplayName.value
          : this.peerDisplayName,
      lastMessage: data.lastMessage.present
          ? data.lastMessage.value
          : this.lastMessage,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsTableData(')
          ..write('id: $id, ')
          ..write('peerNodeId: $peerNodeId, ')
          ..write('peerDisplayName: $peerDisplayName, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    peerNodeId,
    peerDisplayName,
    lastMessage,
    unreadCount,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationsTableData &&
          other.id == this.id &&
          other.peerNodeId == this.peerNodeId &&
          other.peerDisplayName == this.peerDisplayName &&
          other.lastMessage == this.lastMessage &&
          other.unreadCount == this.unreadCount &&
          other.updatedAt == this.updatedAt);
}

class ConversationsTableCompanion
    extends UpdateCompanion<ConversationsTableData> {
  final Value<String> id;
  final Value<String> peerNodeId;
  final Value<String> peerDisplayName;
  final Value<String?> lastMessage;
  final Value<int> unreadCount;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConversationsTableCompanion({
    this.id = const Value.absent(),
    this.peerNodeId = const Value.absent(),
    this.peerDisplayName = const Value.absent(),
    this.lastMessage = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsTableCompanion.insert({
    required String id,
    required String peerNodeId,
    required String peerDisplayName,
    this.lastMessage = const Value.absent(),
    this.unreadCount = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       peerNodeId = Value(peerNodeId),
       peerDisplayName = Value(peerDisplayName),
       updatedAt = Value(updatedAt);
  static Insertable<ConversationsTableData> custom({
    Expression<String>? id,
    Expression<String>? peerNodeId,
    Expression<String>? peerDisplayName,
    Expression<String>? lastMessage,
    Expression<int>? unreadCount,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (peerNodeId != null) 'peer_node_id': peerNodeId,
      if (peerDisplayName != null) 'peer_display_name': peerDisplayName,
      if (lastMessage != null) 'last_message': lastMessage,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? peerNodeId,
    Value<String>? peerDisplayName,
    Value<String?>? lastMessage,
    Value<int>? unreadCount,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConversationsTableCompanion(
      id: id ?? this.id,
      peerNodeId: peerNodeId ?? this.peerNodeId,
      peerDisplayName: peerDisplayName ?? this.peerDisplayName,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (peerNodeId.present) {
      map['peer_node_id'] = Variable<String>(peerNodeId.value);
    }
    if (peerDisplayName.present) {
      map['peer_display_name'] = Variable<String>(peerDisplayName.value);
    }
    if (lastMessage.present) {
      map['last_message'] = Variable<String>(lastMessage.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsTableCompanion(')
          ..write('id: $id, ')
          ..write('peerNodeId: $peerNodeId, ')
          ..write('peerDisplayName: $peerDisplayName, ')
          ..write('lastMessage: $lastMessage, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTableTable extends MessagesTable
    with TableInfo<$MessagesTableTable, MessagesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversations_table (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _senderNodeIdMeta = const VerificationMeta(
    'senderNodeId',
  );
  @override
  late final GeneratedColumn<String> senderNodeId = GeneratedColumn<String>(
    'sender_node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientNodeIdMeta = const VerificationMeta(
    'recipientNodeId',
  );
  @override
  late final GeneratedColumn<String> recipientNodeId = GeneratedColumn<String>(
    'recipient_node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isOutgoingMeta = const VerificationMeta(
    'isOutgoing',
  );
  @override
  late final GeneratedColumn<bool> isOutgoing = GeneratedColumn<bool>(
    'is_outgoing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_outgoing" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    senderNodeId,
    recipientNodeId,
    content,
    timestamp,
    status,
    isOutgoing,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessagesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_node_id')) {
      context.handle(
        _senderNodeIdMeta,
        senderNodeId.isAcceptableOrUnknown(
          data['sender_node_id']!,
          _senderNodeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_senderNodeIdMeta);
    }
    if (data.containsKey('recipient_node_id')) {
      context.handle(
        _recipientNodeIdMeta,
        recipientNodeId.isAcceptableOrUnknown(
          data['recipient_node_id']!,
          _recipientNodeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientNodeIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('is_outgoing')) {
      context.handle(
        _isOutgoingMeta,
        isOutgoing.isAcceptableOrUnknown(data['is_outgoing']!, _isOutgoingMeta),
      );
    } else if (isInserting) {
      context.missing(_isOutgoingMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessagesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessagesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      senderNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_node_id'],
      )!,
      recipientNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_node_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      isOutgoing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_outgoing'],
      )!,
    );
  }

  @override
  $MessagesTableTable createAlias(String alias) {
    return $MessagesTableTable(attachedDatabase, alias);
  }
}

class MessagesTableData extends DataClass
    implements Insertable<MessagesTableData> {
  final String id;
  final String conversationId;
  final String senderNodeId;
  final String recipientNodeId;
  final String content;
  final DateTime timestamp;
  final String status;
  final bool isOutgoing;
  const MessagesTableData({
    required this.id,
    required this.conversationId,
    required this.senderNodeId,
    required this.recipientNodeId,
    required this.content,
    required this.timestamp,
    required this.status,
    required this.isOutgoing,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['sender_node_id'] = Variable<String>(senderNodeId);
    map['recipient_node_id'] = Variable<String>(recipientNodeId);
    map['content'] = Variable<String>(content);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['status'] = Variable<String>(status);
    map['is_outgoing'] = Variable<bool>(isOutgoing);
    return map;
  }

  MessagesTableCompanion toCompanion(bool nullToAbsent) {
    return MessagesTableCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      senderNodeId: Value(senderNodeId),
      recipientNodeId: Value(recipientNodeId),
      content: Value(content),
      timestamp: Value(timestamp),
      status: Value(status),
      isOutgoing: Value(isOutgoing),
    );
  }

  factory MessagesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessagesTableData(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      senderNodeId: serializer.fromJson<String>(json['senderNodeId']),
      recipientNodeId: serializer.fromJson<String>(json['recipientNodeId']),
      content: serializer.fromJson<String>(json['content']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      status: serializer.fromJson<String>(json['status']),
      isOutgoing: serializer.fromJson<bool>(json['isOutgoing']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'senderNodeId': serializer.toJson<String>(senderNodeId),
      'recipientNodeId': serializer.toJson<String>(recipientNodeId),
      'content': serializer.toJson<String>(content),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'status': serializer.toJson<String>(status),
      'isOutgoing': serializer.toJson<bool>(isOutgoing),
    };
  }

  MessagesTableData copyWith({
    String? id,
    String? conversationId,
    String? senderNodeId,
    String? recipientNodeId,
    String? content,
    DateTime? timestamp,
    String? status,
    bool? isOutgoing,
  }) => MessagesTableData(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    senderNodeId: senderNodeId ?? this.senderNodeId,
    recipientNodeId: recipientNodeId ?? this.recipientNodeId,
    content: content ?? this.content,
    timestamp: timestamp ?? this.timestamp,
    status: status ?? this.status,
    isOutgoing: isOutgoing ?? this.isOutgoing,
  );
  MessagesTableData copyWithCompanion(MessagesTableCompanion data) {
    return MessagesTableData(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderNodeId: data.senderNodeId.present
          ? data.senderNodeId.value
          : this.senderNodeId,
      recipientNodeId: data.recipientNodeId.present
          ? data.recipientNodeId.value
          : this.recipientNodeId,
      content: data.content.present ? data.content.value : this.content,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      status: data.status.present ? data.status.value : this.status,
      isOutgoing: data.isOutgoing.present
          ? data.isOutgoing.value
          : this.isOutgoing,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessagesTableData(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderNodeId: $senderNodeId, ')
          ..write('recipientNodeId: $recipientNodeId, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp, ')
          ..write('status: $status, ')
          ..write('isOutgoing: $isOutgoing')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    senderNodeId,
    recipientNodeId,
    content,
    timestamp,
    status,
    isOutgoing,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessagesTableData &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.senderNodeId == this.senderNodeId &&
          other.recipientNodeId == this.recipientNodeId &&
          other.content == this.content &&
          other.timestamp == this.timestamp &&
          other.status == this.status &&
          other.isOutgoing == this.isOutgoing);
}

class MessagesTableCompanion extends UpdateCompanion<MessagesTableData> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> senderNodeId;
  final Value<String> recipientNodeId;
  final Value<String> content;
  final Value<DateTime> timestamp;
  final Value<String> status;
  final Value<bool> isOutgoing;
  final Value<int> rowid;
  const MessagesTableCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderNodeId = const Value.absent(),
    this.recipientNodeId = const Value.absent(),
    this.content = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.status = const Value.absent(),
    this.isOutgoing = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesTableCompanion.insert({
    required String id,
    required String conversationId,
    required String senderNodeId,
    required String recipientNodeId,
    required String content,
    required DateTime timestamp,
    required String status,
    required bool isOutgoing,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       senderNodeId = Value(senderNodeId),
       recipientNodeId = Value(recipientNodeId),
       content = Value(content),
       timestamp = Value(timestamp),
       status = Value(status),
       isOutgoing = Value(isOutgoing);
  static Insertable<MessagesTableData> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? senderNodeId,
    Expression<String>? recipientNodeId,
    Expression<String>? content,
    Expression<DateTime>? timestamp,
    Expression<String>? status,
    Expression<bool>? isOutgoing,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderNodeId != null) 'sender_node_id': senderNodeId,
      if (recipientNodeId != null) 'recipient_node_id': recipientNodeId,
      if (content != null) 'content': content,
      if (timestamp != null) 'timestamp': timestamp,
      if (status != null) 'status': status,
      if (isOutgoing != null) 'is_outgoing': isOutgoing,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? senderNodeId,
    Value<String>? recipientNodeId,
    Value<String>? content,
    Value<DateTime>? timestamp,
    Value<String>? status,
    Value<bool>? isOutgoing,
    Value<int>? rowid,
  }) {
    return MessagesTableCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderNodeId: senderNodeId ?? this.senderNodeId,
      recipientNodeId: recipientNodeId ?? this.recipientNodeId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (senderNodeId.present) {
      map['sender_node_id'] = Variable<String>(senderNodeId.value);
    }
    if (recipientNodeId.present) {
      map['recipient_node_id'] = Variable<String>(recipientNodeId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isOutgoing.present) {
      map['is_outgoing'] = Variable<bool>(isOutgoing.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesTableCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderNodeId: $senderNodeId, ')
          ..write('recipientNodeId: $recipientNodeId, ')
          ..write('content: $content, ')
          ..write('timestamp: $timestamp, ')
          ..write('status: $status, ')
          ..write('isOutgoing: $isOutgoing, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QueuedPacketsTableTable extends QueuedPacketsTable
    with TableInfo<$QueuedPacketsTableTable, QueuedPacketsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueuedPacketsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderNodeIdMeta = const VerificationMeta(
    'senderNodeId',
  );
  @override
  late final GeneratedColumn<String> senderNodeId = GeneratedColumn<String>(
    'sender_node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipientNodeIdMeta = const VerificationMeta(
    'recipientNodeId',
  );
  @override
  late final GeneratedColumn<String> recipientNodeId = GeneratedColumn<String>(
    'recipient_node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageTypeMeta = const VerificationMeta(
    'messageType',
  );
  @override
  late final GeneratedColumn<String> messageType = GeneratedColumn<String>(
    'message_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ttlMeta = const VerificationMeta('ttl');
  @override
  late final GeneratedColumn<int> ttl = GeneratedColumn<int>(
    'ttl',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    senderNodeId,
    recipientNodeId,
    messageType,
    payload,
    timestamp,
    ttl,
    createdAt,
    retryCount,
    nextAttemptAt,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queued_packets_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueuedPacketsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sender_node_id')) {
      context.handle(
        _senderNodeIdMeta,
        senderNodeId.isAcceptableOrUnknown(
          data['sender_node_id']!,
          _senderNodeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_senderNodeIdMeta);
    }
    if (data.containsKey('recipient_node_id')) {
      context.handle(
        _recipientNodeIdMeta,
        recipientNodeId.isAcceptableOrUnknown(
          data['recipient_node_id']!,
          _recipientNodeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recipientNodeIdMeta);
    }
    if (data.containsKey('message_type')) {
      context.handle(
        _messageTypeMeta,
        messageType.isAcceptableOrUnknown(
          data['message_type']!,
          _messageTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_messageTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('ttl')) {
      context.handle(
        _ttlMeta,
        ttl.isAcceptableOrUnknown(data['ttl']!, _ttlMeta),
      );
    } else if (isInserting) {
      context.missing(_ttlMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QueuedPacketsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueuedPacketsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      senderNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_node_id'],
      )!,
      recipientNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipient_node_id'],
      )!,
      messageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      ttl: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ttl'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $QueuedPacketsTableTable createAlias(String alias) {
    return $QueuedPacketsTableTable(attachedDatabase, alias);
  }
}

class QueuedPacketsTableData extends DataClass
    implements Insertable<QueuedPacketsTableData> {
  final String id;
  final String senderNodeId;
  final String recipientNodeId;
  final String messageType;
  final String payload;
  final DateTime timestamp;
  final int ttl;
  final DateTime createdAt;
  final int retryCount;
  final DateTime nextAttemptAt;
  final String status;
  const QueuedPacketsTableData({
    required this.id,
    required this.senderNodeId,
    required this.recipientNodeId,
    required this.messageType,
    required this.payload,
    required this.timestamp,
    required this.ttl,
    required this.createdAt,
    required this.retryCount,
    required this.nextAttemptAt,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sender_node_id'] = Variable<String>(senderNodeId);
    map['recipient_node_id'] = Variable<String>(recipientNodeId);
    map['message_type'] = Variable<String>(messageType);
    map['payload'] = Variable<String>(payload);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['ttl'] = Variable<int>(ttl);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['retry_count'] = Variable<int>(retryCount);
    map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    map['status'] = Variable<String>(status);
    return map;
  }

  QueuedPacketsTableCompanion toCompanion(bool nullToAbsent) {
    return QueuedPacketsTableCompanion(
      id: Value(id),
      senderNodeId: Value(senderNodeId),
      recipientNodeId: Value(recipientNodeId),
      messageType: Value(messageType),
      payload: Value(payload),
      timestamp: Value(timestamp),
      ttl: Value(ttl),
      createdAt: Value(createdAt),
      retryCount: Value(retryCount),
      nextAttemptAt: Value(nextAttemptAt),
      status: Value(status),
    );
  }

  factory QueuedPacketsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueuedPacketsTableData(
      id: serializer.fromJson<String>(json['id']),
      senderNodeId: serializer.fromJson<String>(json['senderNodeId']),
      recipientNodeId: serializer.fromJson<String>(json['recipientNodeId']),
      messageType: serializer.fromJson<String>(json['messageType']),
      payload: serializer.fromJson<String>(json['payload']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      ttl: serializer.fromJson<int>(json['ttl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextAttemptAt: serializer.fromJson<DateTime>(json['nextAttemptAt']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'senderNodeId': serializer.toJson<String>(senderNodeId),
      'recipientNodeId': serializer.toJson<String>(recipientNodeId),
      'messageType': serializer.toJson<String>(messageType),
      'payload': serializer.toJson<String>(payload),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'ttl': serializer.toJson<int>(ttl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextAttemptAt': serializer.toJson<DateTime>(nextAttemptAt),
      'status': serializer.toJson<String>(status),
    };
  }

  QueuedPacketsTableData copyWith({
    String? id,
    String? senderNodeId,
    String? recipientNodeId,
    String? messageType,
    String? payload,
    DateTime? timestamp,
    int? ttl,
    DateTime? createdAt,
    int? retryCount,
    DateTime? nextAttemptAt,
    String? status,
  }) => QueuedPacketsTableData(
    id: id ?? this.id,
    senderNodeId: senderNodeId ?? this.senderNodeId,
    recipientNodeId: recipientNodeId ?? this.recipientNodeId,
    messageType: messageType ?? this.messageType,
    payload: payload ?? this.payload,
    timestamp: timestamp ?? this.timestamp,
    ttl: ttl ?? this.ttl,
    createdAt: createdAt ?? this.createdAt,
    retryCount: retryCount ?? this.retryCount,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    status: status ?? this.status,
  );
  QueuedPacketsTableData copyWithCompanion(QueuedPacketsTableCompanion data) {
    return QueuedPacketsTableData(
      id: data.id.present ? data.id.value : this.id,
      senderNodeId: data.senderNodeId.present
          ? data.senderNodeId.value
          : this.senderNodeId,
      recipientNodeId: data.recipientNodeId.present
          ? data.recipientNodeId.value
          : this.recipientNodeId,
      messageType: data.messageType.present
          ? data.messageType.value
          : this.messageType,
      payload: data.payload.present ? data.payload.value : this.payload,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      ttl: data.ttl.present ? data.ttl.value : this.ttl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueuedPacketsTableData(')
          ..write('id: $id, ')
          ..write('senderNodeId: $senderNodeId, ')
          ..write('recipientNodeId: $recipientNodeId, ')
          ..write('messageType: $messageType, ')
          ..write('payload: $payload, ')
          ..write('timestamp: $timestamp, ')
          ..write('ttl: $ttl, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    senderNodeId,
    recipientNodeId,
    messageType,
    payload,
    timestamp,
    ttl,
    createdAt,
    retryCount,
    nextAttemptAt,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueuedPacketsTableData &&
          other.id == this.id &&
          other.senderNodeId == this.senderNodeId &&
          other.recipientNodeId == this.recipientNodeId &&
          other.messageType == this.messageType &&
          other.payload == this.payload &&
          other.timestamp == this.timestamp &&
          other.ttl == this.ttl &&
          other.createdAt == this.createdAt &&
          other.retryCount == this.retryCount &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.status == this.status);
}

class QueuedPacketsTableCompanion
    extends UpdateCompanion<QueuedPacketsTableData> {
  final Value<String> id;
  final Value<String> senderNodeId;
  final Value<String> recipientNodeId;
  final Value<String> messageType;
  final Value<String> payload;
  final Value<DateTime> timestamp;
  final Value<int> ttl;
  final Value<DateTime> createdAt;
  final Value<int> retryCount;
  final Value<DateTime> nextAttemptAt;
  final Value<String> status;
  final Value<int> rowid;
  const QueuedPacketsTableCompanion({
    this.id = const Value.absent(),
    this.senderNodeId = const Value.absent(),
    this.recipientNodeId = const Value.absent(),
    this.messageType = const Value.absent(),
    this.payload = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.ttl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QueuedPacketsTableCompanion.insert({
    required String id,
    required String senderNodeId,
    required String recipientNodeId,
    required String messageType,
    required String payload,
    required DateTime timestamp,
    required int ttl,
    required DateTime createdAt,
    this.retryCount = const Value.absent(),
    required DateTime nextAttemptAt,
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       senderNodeId = Value(senderNodeId),
       recipientNodeId = Value(recipientNodeId),
       messageType = Value(messageType),
       payload = Value(payload),
       timestamp = Value(timestamp),
       ttl = Value(ttl),
       createdAt = Value(createdAt),
       nextAttemptAt = Value(nextAttemptAt);
  static Insertable<QueuedPacketsTableData> custom({
    Expression<String>? id,
    Expression<String>? senderNodeId,
    Expression<String>? recipientNodeId,
    Expression<String>? messageType,
    Expression<String>? payload,
    Expression<DateTime>? timestamp,
    Expression<int>? ttl,
    Expression<DateTime>? createdAt,
    Expression<int>? retryCount,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (senderNodeId != null) 'sender_node_id': senderNodeId,
      if (recipientNodeId != null) 'recipient_node_id': recipientNodeId,
      if (messageType != null) 'message_type': messageType,
      if (payload != null) 'payload': payload,
      if (timestamp != null) 'timestamp': timestamp,
      if (ttl != null) 'ttl': ttl,
      if (createdAt != null) 'created_at': createdAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QueuedPacketsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? senderNodeId,
    Value<String>? recipientNodeId,
    Value<String>? messageType,
    Value<String>? payload,
    Value<DateTime>? timestamp,
    Value<int>? ttl,
    Value<DateTime>? createdAt,
    Value<int>? retryCount,
    Value<DateTime>? nextAttemptAt,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return QueuedPacketsTableCompanion(
      id: id ?? this.id,
      senderNodeId: senderNodeId ?? this.senderNodeId,
      recipientNodeId: recipientNodeId ?? this.recipientNodeId,
      messageType: messageType ?? this.messageType,
      payload: payload ?? this.payload,
      timestamp: timestamp ?? this.timestamp,
      ttl: ttl ?? this.ttl,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (senderNodeId.present) {
      map['sender_node_id'] = Variable<String>(senderNodeId.value);
    }
    if (recipientNodeId.present) {
      map['recipient_node_id'] = Variable<String>(recipientNodeId.value);
    }
    if (messageType.present) {
      map['message_type'] = Variable<String>(messageType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (ttl.present) {
      map['ttl'] = Variable<int>(ttl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueuedPacketsTableCompanion(')
          ..write('id: $id, ')
          ..write('senderNodeId: $senderNodeId, ')
          ..write('recipientNodeId: $recipientNodeId, ')
          ..write('messageType: $messageType, ')
          ..write('payload: $payload, ')
          ..write('timestamp: $timestamp, ')
          ..write('ttl: $ttl, ')
          ..write('createdAt: $createdAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupsTableTable extends GroupsTable
    with TableInfo<$GroupsTableTable, GroupsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creatorNodeIdMeta = const VerificationMeta(
    'creatorNodeId',
  );
  @override
  late final GeneratedColumn<String> creatorNodeId = GeneratedColumn<String>(
    'creator_node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    creatorNodeId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'groups_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('creator_node_id')) {
      context.handle(
        _creatorNodeIdMeta,
        creatorNodeId.isAcceptableOrUnknown(
          data['creator_node_id']!,
          _creatorNodeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_creatorNodeIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GroupsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      creatorNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creator_node_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GroupsTableTable createAlias(String alias) {
    return $GroupsTableTable(attachedDatabase, alias);
  }
}

class GroupsTableData extends DataClass implements Insertable<GroupsTableData> {
  final String id;
  final String name;
  final String creatorNodeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const GroupsTableData({
    required this.id,
    required this.name,
    required this.creatorNodeId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['creator_node_id'] = Variable<String>(creatorNodeId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GroupsTableCompanion toCompanion(bool nullToAbsent) {
    return GroupsTableCompanion(
      id: Value(id),
      name: Value(name),
      creatorNodeId: Value(creatorNodeId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory GroupsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupsTableData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      creatorNodeId: serializer.fromJson<String>(json['creatorNodeId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'creatorNodeId': serializer.toJson<String>(creatorNodeId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GroupsTableData copyWith({
    String? id,
    String? name,
    String? creatorNodeId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GroupsTableData(
    id: id ?? this.id,
    name: name ?? this.name,
    creatorNodeId: creatorNodeId ?? this.creatorNodeId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GroupsTableData copyWithCompanion(GroupsTableCompanion data) {
    return GroupsTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      creatorNodeId: data.creatorNodeId.present
          ? data.creatorNodeId.value
          : this.creatorNodeId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupsTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('creatorNodeId: $creatorNodeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, creatorNodeId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupsTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.creatorNodeId == this.creatorNodeId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GroupsTableCompanion extends UpdateCompanion<GroupsTableData> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> creatorNodeId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GroupsTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.creatorNodeId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupsTableCompanion.insert({
    required String id,
    required String name,
    required String creatorNodeId,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       creatorNodeId = Value(creatorNodeId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GroupsTableData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? creatorNodeId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (creatorNodeId != null) 'creator_node_id': creatorNodeId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? creatorNodeId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return GroupsTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      creatorNodeId: creatorNodeId ?? this.creatorNodeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (creatorNodeId.present) {
      map['creator_node_id'] = Variable<String>(creatorNodeId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupsTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('creatorNodeId: $creatorNodeId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupMembersTableTable extends GroupMembersTable
    with TableInfo<$GroupMembersTableTable, GroupMembersTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupMembersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES groups_table (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _memberNodeIdMeta = const VerificationMeta(
    'memberNodeId',
  );
  @override
  late final GeneratedColumn<String> memberNodeId = GeneratedColumn<String>(
    'member_node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberDisplayNameMeta = const VerificationMeta(
    'memberDisplayName',
  );
  @override
  late final GeneratedColumn<String> memberDisplayName =
      GeneratedColumn<String>(
        'member_display_name',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _joinedAtMeta = const VerificationMeta(
    'joinedAt',
  );
  @override
  late final GeneratedColumn<DateTime> joinedAt = GeneratedColumn<DateTime>(
    'joined_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    groupId,
    memberNodeId,
    memberDisplayName,
    role,
    joinedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_members_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupMembersTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('member_node_id')) {
      context.handle(
        _memberNodeIdMeta,
        memberNodeId.isAcceptableOrUnknown(
          data['member_node_id']!,
          _memberNodeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_memberNodeIdMeta);
    }
    if (data.containsKey('member_display_name')) {
      context.handle(
        _memberDisplayNameMeta,
        memberDisplayName.isAcceptableOrUnknown(
          data['member_display_name']!,
          _memberDisplayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_memberDisplayNameMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('joined_at')) {
      context.handle(
        _joinedAtMeta,
        joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_joinedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, memberNodeId};
  @override
  GroupMembersTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupMembersTableData(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      memberNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_node_id'],
      )!,
      memberDisplayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_display_name'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      joinedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}joined_at'],
      )!,
    );
  }

  @override
  $GroupMembersTableTable createAlias(String alias) {
    return $GroupMembersTableTable(attachedDatabase, alias);
  }
}

class GroupMembersTableData extends DataClass
    implements Insertable<GroupMembersTableData> {
  final String groupId;
  final String memberNodeId;
  final String memberDisplayName;
  final String role;
  final DateTime joinedAt;
  const GroupMembersTableData({
    required this.groupId,
    required this.memberNodeId,
    required this.memberDisplayName,
    required this.role,
    required this.joinedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['member_node_id'] = Variable<String>(memberNodeId);
    map['member_display_name'] = Variable<String>(memberDisplayName);
    map['role'] = Variable<String>(role);
    map['joined_at'] = Variable<DateTime>(joinedAt);
    return map;
  }

  GroupMembersTableCompanion toCompanion(bool nullToAbsent) {
    return GroupMembersTableCompanion(
      groupId: Value(groupId),
      memberNodeId: Value(memberNodeId),
      memberDisplayName: Value(memberDisplayName),
      role: Value(role),
      joinedAt: Value(joinedAt),
    );
  }

  factory GroupMembersTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupMembersTableData(
      groupId: serializer.fromJson<String>(json['groupId']),
      memberNodeId: serializer.fromJson<String>(json['memberNodeId']),
      memberDisplayName: serializer.fromJson<String>(json['memberDisplayName']),
      role: serializer.fromJson<String>(json['role']),
      joinedAt: serializer.fromJson<DateTime>(json['joinedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'memberNodeId': serializer.toJson<String>(memberNodeId),
      'memberDisplayName': serializer.toJson<String>(memberDisplayName),
      'role': serializer.toJson<String>(role),
      'joinedAt': serializer.toJson<DateTime>(joinedAt),
    };
  }

  GroupMembersTableData copyWith({
    String? groupId,
    String? memberNodeId,
    String? memberDisplayName,
    String? role,
    DateTime? joinedAt,
  }) => GroupMembersTableData(
    groupId: groupId ?? this.groupId,
    memberNodeId: memberNodeId ?? this.memberNodeId,
    memberDisplayName: memberDisplayName ?? this.memberDisplayName,
    role: role ?? this.role,
    joinedAt: joinedAt ?? this.joinedAt,
  );
  GroupMembersTableData copyWithCompanion(GroupMembersTableCompanion data) {
    return GroupMembersTableData(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      memberNodeId: data.memberNodeId.present
          ? data.memberNodeId.value
          : this.memberNodeId,
      memberDisplayName: data.memberDisplayName.present
          ? data.memberDisplayName.value
          : this.memberDisplayName,
      role: data.role.present ? data.role.value : this.role,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupMembersTableData(')
          ..write('groupId: $groupId, ')
          ..write('memberNodeId: $memberNodeId, ')
          ..write('memberDisplayName: $memberDisplayName, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(groupId, memberNodeId, memberDisplayName, role, joinedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupMembersTableData &&
          other.groupId == this.groupId &&
          other.memberNodeId == this.memberNodeId &&
          other.memberDisplayName == this.memberDisplayName &&
          other.role == this.role &&
          other.joinedAt == this.joinedAt);
}

class GroupMembersTableCompanion
    extends UpdateCompanion<GroupMembersTableData> {
  final Value<String> groupId;
  final Value<String> memberNodeId;
  final Value<String> memberDisplayName;
  final Value<String> role;
  final Value<DateTime> joinedAt;
  final Value<int> rowid;
  const GroupMembersTableCompanion({
    this.groupId = const Value.absent(),
    this.memberNodeId = const Value.absent(),
    this.memberDisplayName = const Value.absent(),
    this.role = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupMembersTableCompanion.insert({
    required String groupId,
    required String memberNodeId,
    required String memberDisplayName,
    required String role,
    required DateTime joinedAt,
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId),
       memberNodeId = Value(memberNodeId),
       memberDisplayName = Value(memberDisplayName),
       role = Value(role),
       joinedAt = Value(joinedAt);
  static Insertable<GroupMembersTableData> custom({
    Expression<String>? groupId,
    Expression<String>? memberNodeId,
    Expression<String>? memberDisplayName,
    Expression<String>? role,
    Expression<DateTime>? joinedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (memberNodeId != null) 'member_node_id': memberNodeId,
      if (memberDisplayName != null) 'member_display_name': memberDisplayName,
      if (role != null) 'role': role,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupMembersTableCompanion copyWith({
    Value<String>? groupId,
    Value<String>? memberNodeId,
    Value<String>? memberDisplayName,
    Value<String>? role,
    Value<DateTime>? joinedAt,
    Value<int>? rowid,
  }) {
    return GroupMembersTableCompanion(
      groupId: groupId ?? this.groupId,
      memberNodeId: memberNodeId ?? this.memberNodeId,
      memberDisplayName: memberDisplayName ?? this.memberDisplayName,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (memberNodeId.present) {
      map['member_node_id'] = Variable<String>(memberNodeId.value);
    }
    if (memberDisplayName.present) {
      map['member_display_name'] = Variable<String>(memberDisplayName.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<DateTime>(joinedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupMembersTableCompanion(')
          ..write('groupId: $groupId, ')
          ..write('memberNodeId: $memberNodeId, ')
          ..write('memberDisplayName: $memberDisplayName, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$OfflinkDatabase extends GeneratedDatabase {
  _$OfflinkDatabase(QueryExecutor e) : super(e);
  $OfflinkDatabaseManager get managers => $OfflinkDatabaseManager(this);
  late final $ConversationsTableTable conversationsTable =
      $ConversationsTableTable(this);
  late final $MessagesTableTable messagesTable = $MessagesTableTable(this);
  late final $QueuedPacketsTableTable queuedPacketsTable =
      $QueuedPacketsTableTable(this);
  late final $GroupsTableTable groupsTable = $GroupsTableTable(this);
  late final $GroupMembersTableTable groupMembersTable =
      $GroupMembersTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    conversationsTable,
    messagesTable,
    queuedPacketsTable,
    groupsTable,
    groupMembersTable,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversations_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('messages_table', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'groups_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('group_members_table', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ConversationsTableTableCreateCompanionBuilder =
    ConversationsTableCompanion Function({
      required String id,
      required String peerNodeId,
      required String peerDisplayName,
      Value<String?> lastMessage,
      Value<int> unreadCount,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ConversationsTableTableUpdateCompanionBuilder =
    ConversationsTableCompanion Function({
      Value<String> id,
      Value<String> peerNodeId,
      Value<String> peerDisplayName,
      Value<String?> lastMessage,
      Value<int> unreadCount,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ConversationsTableTableReferences
    extends
        BaseReferences<
          _$OfflinkDatabase,
          $ConversationsTableTable,
          ConversationsTableData
        > {
  $$ConversationsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$MessagesTableTable, List<MessagesTableData>>
  _messagesTableRefsTable(_$OfflinkDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.messagesTable,
        aliasName: 'conversations_table__id__messages_table__conversation_id',
      );

  $$MessagesTableTableProcessedTableManager get messagesTableRefs {
    final manager = $$MessagesTableTableTableManager(
      $_db,
      $_db.messagesTable,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_messagesTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ConversationsTableTableFilterComposer
    extends Composer<_$OfflinkDatabase, $ConversationsTableTable> {
  $$ConversationsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerNodeId => $composableBuilder(
    column: $table.peerNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerDisplayName => $composableBuilder(
    column: $table.peerDisplayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> messagesTableRefs(
    Expression<bool> Function($$MessagesTableTableFilterComposer f) f,
  ) {
    final $$MessagesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messagesTable,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableTableFilterComposer(
            $db: $db,
            $table: $db.messagesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableTableOrderingComposer
    extends Composer<_$OfflinkDatabase, $ConversationsTableTable> {
  $$ConversationsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerNodeId => $composableBuilder(
    column: $table.peerNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerDisplayName => $composableBuilder(
    column: $table.peerDisplayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationsTableTableAnnotationComposer
    extends Composer<_$OfflinkDatabase, $ConversationsTableTable> {
  $$ConversationsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get peerNodeId => $composableBuilder(
    column: $table.peerNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get peerDisplayName => $composableBuilder(
    column: $table.peerDisplayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessage => $composableBuilder(
    column: $table.lastMessage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> messagesTableRefs<T extends Object>(
    Expression<T> Function($$MessagesTableTableAnnotationComposer a) f,
  ) {
    final $$MessagesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.messagesTable,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MessagesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.messagesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableTableTableManager
    extends
        RootTableManager<
          _$OfflinkDatabase,
          $ConversationsTableTable,
          ConversationsTableData,
          $$ConversationsTableTableFilterComposer,
          $$ConversationsTableTableOrderingComposer,
          $$ConversationsTableTableAnnotationComposer,
          $$ConversationsTableTableCreateCompanionBuilder,
          $$ConversationsTableTableUpdateCompanionBuilder,
          (ConversationsTableData, $$ConversationsTableTableReferences),
          ConversationsTableData,
          PrefetchHooks Function({bool messagesTableRefs})
        > {
  $$ConversationsTableTableTableManager(
    _$OfflinkDatabase db,
    $ConversationsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> peerNodeId = const Value.absent(),
                Value<String> peerDisplayName = const Value.absent(),
                Value<String?> lastMessage = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsTableCompanion(
                id: id,
                peerNodeId: peerNodeId,
                peerDisplayName: peerDisplayName,
                lastMessage: lastMessage,
                unreadCount: unreadCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String peerNodeId,
                required String peerDisplayName,
                Value<String?> lastMessage = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ConversationsTableCompanion.insert(
                id: id,
                peerNodeId: peerNodeId,
                peerDisplayName: peerDisplayName,
                lastMessage: lastMessage,
                unreadCount: unreadCount,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConversationsTableTable, ConversationsTableData>(
                    table,
                  ),
                  $$ConversationsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({messagesTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (messagesTableRefs) db.messagesTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (messagesTableRefs)
                    await $_getPrefetchedData<
                      ConversationsTableData,
                      $ConversationsTableTable,
                      MessagesTableData
                    >(
                      currentTable: table,
                      referencedTable: $$ConversationsTableTableReferences
                          ._messagesTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ConversationsTableTableReferences(
                            db,
                            table,
                            p0,
                          ).messagesTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.conversationId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ConversationsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflinkDatabase,
      $ConversationsTableTable,
      ConversationsTableData,
      $$ConversationsTableTableFilterComposer,
      $$ConversationsTableTableOrderingComposer,
      $$ConversationsTableTableAnnotationComposer,
      $$ConversationsTableTableCreateCompanionBuilder,
      $$ConversationsTableTableUpdateCompanionBuilder,
      (ConversationsTableData, $$ConversationsTableTableReferences),
      ConversationsTableData,
      PrefetchHooks Function({bool messagesTableRefs})
    >;
typedef $$MessagesTableTableCreateCompanionBuilder =
    MessagesTableCompanion Function({
      required String id,
      required String conversationId,
      required String senderNodeId,
      required String recipientNodeId,
      required String content,
      required DateTime timestamp,
      required String status,
      required bool isOutgoing,
      Value<int> rowid,
    });
typedef $$MessagesTableTableUpdateCompanionBuilder =
    MessagesTableCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> senderNodeId,
      Value<String> recipientNodeId,
      Value<String> content,
      Value<DateTime> timestamp,
      Value<String> status,
      Value<bool> isOutgoing,
      Value<int> rowid,
    });

final class $$MessagesTableTableReferences
    extends
        BaseReferences<
          _$OfflinkDatabase,
          $MessagesTableTable,
          MessagesTableData
        > {
  $$MessagesTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ConversationsTableTable _conversationIdTable(_$OfflinkDatabase db) =>
      db.conversationsTable.createAlias(
        'messages_table__conversation_id__conversations_table__id',
      );

  $$ConversationsTableTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableTableManager(
      $_db,
      $_db.conversationsTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MessagesTableTableFilterComposer
    extends Composer<_$OfflinkDatabase, $MessagesTableTable> {
  $$MessagesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderNodeId => $composableBuilder(
    column: $table.senderNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientNodeId => $composableBuilder(
    column: $table.recipientNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOutgoing => $composableBuilder(
    column: $table.isOutgoing,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationsTableTableFilterComposer get conversationId {
    final $$ConversationsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversationsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableTableFilterComposer(
            $db: $db,
            $table: $db.conversationsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableTableOrderingComposer
    extends Composer<_$OfflinkDatabase, $MessagesTableTable> {
  $$MessagesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderNodeId => $composableBuilder(
    column: $table.senderNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientNodeId => $composableBuilder(
    column: $table.recipientNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOutgoing => $composableBuilder(
    column: $table.isOutgoing,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationsTableTableOrderingComposer get conversationId {
    final $$ConversationsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversationsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableTableOrderingComposer(
            $db: $db,
            $table: $db.conversationsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MessagesTableTableAnnotationComposer
    extends Composer<_$OfflinkDatabase, $MessagesTableTable> {
  $$MessagesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get senderNodeId => $composableBuilder(
    column: $table.senderNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientNodeId => $composableBuilder(
    column: $table.recipientNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isOutgoing => $composableBuilder(
    column: $table.isOutgoing,
    builder: (column) => column,
  );

  $$ConversationsTableTableAnnotationComposer get conversationId {
    final $$ConversationsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.conversationId,
          referencedTable: $db.conversationsTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.conversationsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$MessagesTableTableTableManager
    extends
        RootTableManager<
          _$OfflinkDatabase,
          $MessagesTableTable,
          MessagesTableData,
          $$MessagesTableTableFilterComposer,
          $$MessagesTableTableOrderingComposer,
          $$MessagesTableTableAnnotationComposer,
          $$MessagesTableTableCreateCompanionBuilder,
          $$MessagesTableTableUpdateCompanionBuilder,
          (MessagesTableData, $$MessagesTableTableReferences),
          MessagesTableData,
          PrefetchHooks Function({bool conversationId})
        > {
  $$MessagesTableTableTableManager(
    _$OfflinkDatabase db,
    $MessagesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> senderNodeId = const Value.absent(),
                Value<String> recipientNodeId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isOutgoing = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesTableCompanion(
                id: id,
                conversationId: conversationId,
                senderNodeId: senderNodeId,
                recipientNodeId: recipientNodeId,
                content: content,
                timestamp: timestamp,
                status: status,
                isOutgoing: isOutgoing,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String senderNodeId,
                required String recipientNodeId,
                required String content,
                required DateTime timestamp,
                required String status,
                required bool isOutgoing,
                Value<int> rowid = const Value.absent(),
              }) => MessagesTableCompanion.insert(
                id: id,
                conversationId: conversationId,
                senderNodeId: senderNodeId,
                recipientNodeId: recipientNodeId,
                content: content,
                timestamp: timestamp,
                status: status,
                isOutgoing: isOutgoing,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MessagesTableTable, MessagesTableData>(table),
                  $$MessagesTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (conversationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.conversationId,
                                referencedTable: $$MessagesTableTableReferences
                                    ._conversationIdTable(db),
                                referencedColumn: $$MessagesTableTableReferences
                                    ._conversationIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MessagesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflinkDatabase,
      $MessagesTableTable,
      MessagesTableData,
      $$MessagesTableTableFilterComposer,
      $$MessagesTableTableOrderingComposer,
      $$MessagesTableTableAnnotationComposer,
      $$MessagesTableTableCreateCompanionBuilder,
      $$MessagesTableTableUpdateCompanionBuilder,
      (MessagesTableData, $$MessagesTableTableReferences),
      MessagesTableData,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$QueuedPacketsTableTableCreateCompanionBuilder =
    QueuedPacketsTableCompanion Function({
      required String id,
      required String senderNodeId,
      required String recipientNodeId,
      required String messageType,
      required String payload,
      required DateTime timestamp,
      required int ttl,
      required DateTime createdAt,
      Value<int> retryCount,
      required DateTime nextAttemptAt,
      Value<String> status,
      Value<int> rowid,
    });
typedef $$QueuedPacketsTableTableUpdateCompanionBuilder =
    QueuedPacketsTableCompanion Function({
      Value<String> id,
      Value<String> senderNodeId,
      Value<String> recipientNodeId,
      Value<String> messageType,
      Value<String> payload,
      Value<DateTime> timestamp,
      Value<int> ttl,
      Value<DateTime> createdAt,
      Value<int> retryCount,
      Value<DateTime> nextAttemptAt,
      Value<String> status,
      Value<int> rowid,
    });

class $$QueuedPacketsTableTableFilterComposer
    extends Composer<_$OfflinkDatabase, $QueuedPacketsTableTable> {
  $$QueuedPacketsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderNodeId => $composableBuilder(
    column: $table.senderNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recipientNodeId => $composableBuilder(
    column: $table.recipientNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QueuedPacketsTableTableOrderingComposer
    extends Composer<_$OfflinkDatabase, $QueuedPacketsTableTable> {
  $$QueuedPacketsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderNodeId => $composableBuilder(
    column: $table.senderNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recipientNodeId => $composableBuilder(
    column: $table.recipientNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ttl => $composableBuilder(
    column: $table.ttl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QueuedPacketsTableTableAnnotationComposer
    extends Composer<_$OfflinkDatabase, $QueuedPacketsTableTable> {
  $$QueuedPacketsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get senderNodeId => $composableBuilder(
    column: $table.senderNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recipientNodeId => $composableBuilder(
    column: $table.recipientNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get messageType => $composableBuilder(
    column: $table.messageType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get ttl =>
      $composableBuilder(column: $table.ttl, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$QueuedPacketsTableTableTableManager
    extends
        RootTableManager<
          _$OfflinkDatabase,
          $QueuedPacketsTableTable,
          QueuedPacketsTableData,
          $$QueuedPacketsTableTableFilterComposer,
          $$QueuedPacketsTableTableOrderingComposer,
          $$QueuedPacketsTableTableAnnotationComposer,
          $$QueuedPacketsTableTableCreateCompanionBuilder,
          $$QueuedPacketsTableTableUpdateCompanionBuilder,
          (
            QueuedPacketsTableData,
            BaseReferences<
              _$OfflinkDatabase,
              $QueuedPacketsTableTable,
              QueuedPacketsTableData
            >,
          ),
          QueuedPacketsTableData,
          PrefetchHooks Function()
        > {
  $$QueuedPacketsTableTableTableManager(
    _$OfflinkDatabase db,
    $QueuedPacketsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueuedPacketsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueuedPacketsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueuedPacketsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> senderNodeId = const Value.absent(),
                Value<String> recipientNodeId = const Value.absent(),
                Value<String> messageType = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<int> ttl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<DateTime> nextAttemptAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QueuedPacketsTableCompanion(
                id: id,
                senderNodeId: senderNodeId,
                recipientNodeId: recipientNodeId,
                messageType: messageType,
                payload: payload,
                timestamp: timestamp,
                ttl: ttl,
                createdAt: createdAt,
                retryCount: retryCount,
                nextAttemptAt: nextAttemptAt,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String senderNodeId,
                required String recipientNodeId,
                required String messageType,
                required String payload,
                required DateTime timestamp,
                required int ttl,
                required DateTime createdAt,
                Value<int> retryCount = const Value.absent(),
                required DateTime nextAttemptAt,
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QueuedPacketsTableCompanion.insert(
                id: id,
                senderNodeId: senderNodeId,
                recipientNodeId: recipientNodeId,
                messageType: messageType,
                payload: payload,
                timestamp: timestamp,
                ttl: ttl,
                createdAt: createdAt,
                retryCount: retryCount,
                nextAttemptAt: nextAttemptAt,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QueuedPacketsTableTable, QueuedPacketsTableData>(
                    table,
                  ),
                  BaseReferences<
                    _$OfflinkDatabase,
                    $QueuedPacketsTableTable,
                    QueuedPacketsTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QueuedPacketsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflinkDatabase,
      $QueuedPacketsTableTable,
      QueuedPacketsTableData,
      $$QueuedPacketsTableTableFilterComposer,
      $$QueuedPacketsTableTableOrderingComposer,
      $$QueuedPacketsTableTableAnnotationComposer,
      $$QueuedPacketsTableTableCreateCompanionBuilder,
      $$QueuedPacketsTableTableUpdateCompanionBuilder,
      (
        QueuedPacketsTableData,
        BaseReferences<
          _$OfflinkDatabase,
          $QueuedPacketsTableTable,
          QueuedPacketsTableData
        >,
      ),
      QueuedPacketsTableData,
      PrefetchHooks Function()
    >;
typedef $$GroupsTableTableCreateCompanionBuilder =
    GroupsTableCompanion Function({
      required String id,
      required String name,
      required String creatorNodeId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$GroupsTableTableUpdateCompanionBuilder =
    GroupsTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> creatorNodeId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$GroupsTableTableReferences
    extends
        BaseReferences<_$OfflinkDatabase, $GroupsTableTable, GroupsTableData> {
  $$GroupsTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $GroupMembersTableTable,
    List<GroupMembersTableData>
  >
  _groupMembersTableRefsTable(_$OfflinkDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.groupMembersTable,
        aliasName: 'groups_table__id__group_members_table__group_id',
      );

  $$GroupMembersTableTableProcessedTableManager get groupMembersTableRefs {
    final manager = $$GroupMembersTableTableTableManager(
      $_db,
      $_db.groupMembersTable,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _groupMembersTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GroupsTableTableFilterComposer
    extends Composer<_$OfflinkDatabase, $GroupsTableTable> {
  $$GroupsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatorNodeId => $composableBuilder(
    column: $table.creatorNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> groupMembersTableRefs(
    Expression<bool> Function($$GroupMembersTableTableFilterComposer f) f,
  ) {
    final $$GroupMembersTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.groupMembersTable,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupMembersTableTableFilterComposer(
            $db: $db,
            $table: $db.groupMembersTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GroupsTableTableOrderingComposer
    extends Composer<_$OfflinkDatabase, $GroupsTableTable> {
  $$GroupsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatorNodeId => $composableBuilder(
    column: $table.creatorNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupsTableTableAnnotationComposer
    extends Composer<_$OfflinkDatabase, $GroupsTableTable> {
  $$GroupsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get creatorNodeId => $composableBuilder(
    column: $table.creatorNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> groupMembersTableRefs<T extends Object>(
    Expression<T> Function($$GroupMembersTableTableAnnotationComposer a) f,
  ) {
    final $$GroupMembersTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.groupMembersTable,
          getReferencedColumn: (t) => t.groupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GroupMembersTableTableAnnotationComposer(
                $db: $db,
                $table: $db.groupMembersTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$GroupsTableTableTableManager
    extends
        RootTableManager<
          _$OfflinkDatabase,
          $GroupsTableTable,
          GroupsTableData,
          $$GroupsTableTableFilterComposer,
          $$GroupsTableTableOrderingComposer,
          $$GroupsTableTableAnnotationComposer,
          $$GroupsTableTableCreateCompanionBuilder,
          $$GroupsTableTableUpdateCompanionBuilder,
          (GroupsTableData, $$GroupsTableTableReferences),
          GroupsTableData,
          PrefetchHooks Function({bool groupMembersTableRefs})
        > {
  $$GroupsTableTableTableManager(_$OfflinkDatabase db, $GroupsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> creatorNodeId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsTableCompanion(
                id: id,
                name: name,
                creatorNodeId: creatorNodeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String creatorNodeId,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GroupsTableCompanion.insert(
                id: id,
                name: name,
                creatorNodeId: creatorNodeId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GroupsTableTable, GroupsTableData>(table),
                  $$GroupsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupMembersTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (groupMembersTableRefs) db.groupMembersTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (groupMembersTableRefs)
                    await $_getPrefetchedData<
                      GroupsTableData,
                      $GroupsTableTable,
                      GroupMembersTableData
                    >(
                      currentTable: table,
                      referencedTable: $$GroupsTableTableReferences
                          ._groupMembersTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$GroupsTableTableReferences(
                            db,
                            table,
                            p0,
                          ).groupMembersTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.groupId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$GroupsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflinkDatabase,
      $GroupsTableTable,
      GroupsTableData,
      $$GroupsTableTableFilterComposer,
      $$GroupsTableTableOrderingComposer,
      $$GroupsTableTableAnnotationComposer,
      $$GroupsTableTableCreateCompanionBuilder,
      $$GroupsTableTableUpdateCompanionBuilder,
      (GroupsTableData, $$GroupsTableTableReferences),
      GroupsTableData,
      PrefetchHooks Function({bool groupMembersTableRefs})
    >;
typedef $$GroupMembersTableTableCreateCompanionBuilder =
    GroupMembersTableCompanion Function({
      required String groupId,
      required String memberNodeId,
      required String memberDisplayName,
      required String role,
      required DateTime joinedAt,
      Value<int> rowid,
    });
typedef $$GroupMembersTableTableUpdateCompanionBuilder =
    GroupMembersTableCompanion Function({
      Value<String> groupId,
      Value<String> memberNodeId,
      Value<String> memberDisplayName,
      Value<String> role,
      Value<DateTime> joinedAt,
      Value<int> rowid,
    });

final class $$GroupMembersTableTableReferences
    extends
        BaseReferences<
          _$OfflinkDatabase,
          $GroupMembersTableTable,
          GroupMembersTableData
        > {
  $$GroupMembersTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GroupsTableTable _groupIdTable(_$OfflinkDatabase db) => db.groupsTable
      .createAlias('group_members_table__group_id__groups_table__id');

  $$GroupsTableTableProcessedTableManager get groupId {
    final $_column = $_itemColumn<String>('group_id')!;

    final manager = $$GroupsTableTableTableManager(
      $_db,
      $_db.groupsTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GroupMembersTableTableFilterComposer
    extends Composer<_$OfflinkDatabase, $GroupMembersTableTable> {
  $$GroupMembersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get memberNodeId => $composableBuilder(
    column: $table.memberNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memberDisplayName => $composableBuilder(
    column: $table.memberDisplayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableTableFilterComposer get groupId {
    final $$GroupsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groupsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableTableFilterComposer(
            $db: $db,
            $table: $db.groupsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableTableOrderingComposer
    extends Composer<_$OfflinkDatabase, $GroupMembersTableTable> {
  $$GroupMembersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get memberNodeId => $composableBuilder(
    column: $table.memberNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memberDisplayName => $composableBuilder(
    column: $table.memberDisplayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableTableOrderingComposer get groupId {
    final $$GroupsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groupsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableTableOrderingComposer(
            $db: $db,
            $table: $db.groupsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableTableAnnotationComposer
    extends Composer<_$OfflinkDatabase, $GroupMembersTableTable> {
  $$GroupMembersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get memberNodeId => $composableBuilder(
    column: $table.memberNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get memberDisplayName => $composableBuilder(
    column: $table.memberDisplayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<DateTime> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  $$GroupsTableTableAnnotationComposer get groupId {
    final $$GroupsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groupsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.groupsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GroupMembersTableTableTableManager
    extends
        RootTableManager<
          _$OfflinkDatabase,
          $GroupMembersTableTable,
          GroupMembersTableData,
          $$GroupMembersTableTableFilterComposer,
          $$GroupMembersTableTableOrderingComposer,
          $$GroupMembersTableTableAnnotationComposer,
          $$GroupMembersTableTableCreateCompanionBuilder,
          $$GroupMembersTableTableUpdateCompanionBuilder,
          (GroupMembersTableData, $$GroupMembersTableTableReferences),
          GroupMembersTableData,
          PrefetchHooks Function({bool groupId})
        > {
  $$GroupMembersTableTableTableManager(
    _$OfflinkDatabase db,
    $GroupMembersTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupMembersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupMembersTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupMembersTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> groupId = const Value.absent(),
                Value<String> memberNodeId = const Value.absent(),
                Value<String> memberDisplayName = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<DateTime> joinedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersTableCompanion(
                groupId: groupId,
                memberNodeId: memberNodeId,
                memberDisplayName: memberDisplayName,
                role: role,
                joinedAt: joinedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupId,
                required String memberNodeId,
                required String memberDisplayName,
                required String role,
                required DateTime joinedAt,
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersTableCompanion.insert(
                groupId: groupId,
                memberNodeId: memberNodeId,
                memberDisplayName: memberDisplayName,
                role: role,
                joinedAt: joinedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GroupMembersTableTable, GroupMembersTableData>(
                    table,
                  ),
                  $$GroupMembersTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({groupId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (groupId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.groupId,
                                referencedTable:
                                    $$GroupMembersTableTableReferences
                                        ._groupIdTable(db),
                                referencedColumn:
                                    $$GroupMembersTableTableReferences
                                        ._groupIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GroupMembersTableTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflinkDatabase,
      $GroupMembersTableTable,
      GroupMembersTableData,
      $$GroupMembersTableTableFilterComposer,
      $$GroupMembersTableTableOrderingComposer,
      $$GroupMembersTableTableAnnotationComposer,
      $$GroupMembersTableTableCreateCompanionBuilder,
      $$GroupMembersTableTableUpdateCompanionBuilder,
      (GroupMembersTableData, $$GroupMembersTableTableReferences),
      GroupMembersTableData,
      PrefetchHooks Function({bool groupId})
    >;

class $OfflinkDatabaseManager {
  final _$OfflinkDatabase _db;
  $OfflinkDatabaseManager(this._db);
  $$ConversationsTableTableTableManager get conversationsTable =>
      $$ConversationsTableTableTableManager(_db, _db.conversationsTable);
  $$MessagesTableTableTableManager get messagesTable =>
      $$MessagesTableTableTableManager(_db, _db.messagesTable);
  $$QueuedPacketsTableTableTableManager get queuedPacketsTable =>
      $$QueuedPacketsTableTableTableManager(_db, _db.queuedPacketsTable);
  $$GroupsTableTableTableManager get groupsTable =>
      $$GroupsTableTableTableManager(_db, _db.groupsTable);
  $$GroupMembersTableTableTableManager get groupMembersTable =>
      $$GroupMembersTableTableTableManager(_db, _db.groupMembersTable);
}
