import 'dart:developer';

import 'lib/collectors/api_monitor.dart';
import 'lib/collectors/cpu_collector.dart';
import 'lib/collectors/disk_collector.dart';
import 'lib/collectors/fs_collector.dart';
import 'lib/collectors/memory_collector.dart';
import 'lib/collectors/netstat_collector.dart';
import 'lib/collectors/network_collector.dart';
import 'lib/collectors/process_collector.dart';
import 'lib/collectors/system_collector.dart';
import 'lib/collectors/user_collector.dart';

void main() async {
  print('Testing SystemCollector...');
  try {
    print(await SystemCollector.collect());
  } catch (e) {
    log('Exception caught', error: e);
    print('FAIL SystemCollector: $e');
  }

  print('Testing CpuCollector...');
  try {
    print(await CpuCollector.collect());
  } catch (e) {
    log('Exception caught', error: e);
    print('FAIL CpuCollector: $e');
  }

  print('Testing MemoryCollector...');
  try {
    print(await MemoryCollector.collect());
  } catch (e) {
    log('Exception caught', error: e);
    print('FAIL MemoryCollector: $e');
  }

  print('Testing DiskCollector...');
  try {
    print(await DiskCollector.collect());
  } catch (e) {
    log('Exception caught', error: e);
    print('FAIL DiskCollector: $e');
  }

  print('Testing FsCollector...');
  try {
    print(await FsCollector.collect());
  } catch (e) {
    log('Exception caught', error: e);
    print('FAIL FsCollector: $e');
  }

  print('Testing NetworkCollector...');
  try {
    print(await NetworkCollector.collect());
  } catch (e) {
    log('Exception caught', error: e);
    print('FAIL NetworkCollector: $e');
  }

  print('Testing NetstatCollector...');
  try {
    print(await NetstatCollector.collect());
  } catch (e) {
    log('Exception caught', error: e);
    print('FAIL NetstatCollector: $e');
  }

  print('Testing ProcessCollector...');
  try {
    print(await ProcessCollector.collect());
  } catch (e) {
    log('Exception caught', error: e);
    print('FAIL ProcessCollector: $e');
  }

  print('Testing UserCollector...');
  try {
    print(await UserCollector.collect());
  } catch (e) {
    log('Exception caught', error: e);
    print('FAIL UserCollector: $e');
  }

  print('Testing ApiMonitor...');
  try {
    print(await ApiMonitor.collect());
  } catch (e) {
    log('Exception caught', error: e);
    print('FAIL ApiMonitor: $e');
  }
}
