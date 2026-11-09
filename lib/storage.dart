import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'model.dart';

class Storage {
  late Database _db;
  Future<Book> open() async {
    final folder = await getApplicationSupportDirectory();
    _db = await openDatabase(
      '${folder.path}/warm-ledger.db',
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE state (id INTEGER PRIMARY KEY, payload TEXT NOT NULL)',
      ),
    );
    final rows = await _db.query('state', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return Book();
    // Never silently overwrite an unreadable ledger with an empty one.
    return Book.fromJson(object(jsonDecode(rows.first['payload'] as String)));
  }

  Future<void> save(Book b) => _db.transaction((tx) async {
    await tx.insert('state', {
      'id': 1,
      'payload': jsonEncode(b.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
  Future<bool> backup(Book b) async {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(b.toJson())));
    final saved = await FilePicker.platform.saveFile(
      dialogTitle: '保存完整离线备份',
      fileName: '暖账-完整备份-${today()}.json',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    return saved != null;
  }

  Future<Book?> importBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: false,
    );
    if (picked == null) return null;
    final file = File(picked.files.single.path!);
    if (await file.length() > 64 * 1024 * 1024) {
      throw const FormatException('备份超过64MB，请先减少图片附件');
    }
    return Book.fromJson(object(jsonDecode(await file.readAsString())));
  }

  Future<bool> csv(Book b) async {
    // Prefix spreadsheet formula-like text to prevent CSV formula execution.
    String cell(String text) {
      if (RegExp(r'^\s*[=+@\-]').hasMatch(text)) text = "'$text";
      return '"${text.replaceAll('"', '""')}"';
    }

    final lines = <List<String>>[
      [
        '日期',
        '类型',
        '分类',
        '支出',
        '收入',
        '账户变化',
        '应收变化',
        '备注',
        '代管变化',
        '固定开支月份',
        '状态',
        '是否计入计划',
        '代管承担',
      ],
      ...b.entries.map(
        (e) => [
          e.date,
          e.kind,
          e.category,
          number(e.expense),
          number(e.income),
          e.cash.entries
              .map(
                (m) =>
                    '${b.wallets.firstWhere((w) => w.id == m.key).name}:${number(m.value)}',
              )
              .join('；'),
          e.claims.entries
              .map(
                (m) =>
                    '${b.claims.firstWhere((c) => c.id == m.key).title}:${number(m.value)}',
              )
              .join('；'),
          e.note,
          e.holdings.entries
              .map(
                (h) =>
                    '${b.custodies.firstWhere((c) => c.id == h.key).owner}:${number(h.value)}',
              )
              .join('；'),
          e.fixedMonth,
          e.voided ? '已作废' : '有效',
          e.countsForPlan ? '是' : '否',
          number(e.custodyCovered),
        ],
      ),
    ];
    final output =
        '\ufeff${lines.map((r) => r.map(cell).join(',')).join('\r\n')}';
    final saved = await FilePicker.platform.saveFile(
      dialogTitle: '导出流水CSV',
      fileName: '暖账-流水-${today()}.csv',
      bytes: Uint8List.fromList(utf8.encode(output)),
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    return saved != null;
  }
}

class Alerts {
  final plugin = FlutterLocalNotificationsPlugin();
  bool ready = false;
  Future<void> initialize() async {
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_leaf'),
      ),
    );
    ready = true;
  }

  Future<bool> ask() async =>
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission() ??
      false;
  Future<void> show(List<String> labels) async {
    if (!ready || labels.isEmpty) return;
    await plugin.show(
      1,
      '暖账 · 预算或底线已突破',
      labels.join('、'),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_breaches',
          '预算与底线突破',
          channelDescription: '仅在预算或底线从正常变为突破时提醒',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }
}
