import 'dart:io';
import 'package:yaml/yaml.dart';

void main() {
  final content = File('/opt/monitro/config/monitro.yaml').readAsStringSync();
  final config = loadYaml(content) as YamlMap;
  final db = config['database'] as YamlMap;
  print('Parsed password: [${db['password']}]');
}
