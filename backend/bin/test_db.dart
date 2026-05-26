import 'dart:developer';
import 'dart:io';
import 'package:mysql_client/mysql_client.dart';
import 'package:yaml/yaml.dart';

Future<void> main() async {
  final content = File('/opt/monitro/config/monitro.yaml').readAsStringSync();
  final config = loadYaml(content) as YamlMap;
  final db = config['database'] as YamlMap;

  final user = db['user'] as String;
  final password = db['password'] as String;

  print('Attempting connection to 127.0.0.1 with user=[$user] password=[$password]');

  try {
    final conn = await MySQLConnection.createConnection(
      host: '127.0.0.1',
      port: 3306,
      userName: user,
      password: password,
      databaseName: db['name'] as String,
      secure: false,
    );
    await conn.connect();
    print('SUCCESS!');
    await conn.close();
  } catch (e) {
      log('Exception caught', error: e);
    print('ERROR: $e');
  }
}
