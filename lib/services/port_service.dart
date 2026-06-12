import 'dart:convert';
import 'dart:io';

import '../models/port_info.dart';

class PortService {
  Future<List<PortInfo>> getPorts() async {
    if (Platform.isMacOS) {
      return _getMacOSPorts();
    } else if (Platform.isWindows) {
      return _getWindowsPorts();
    }
    throw UnsupportedError('当前平台不支持');
  }

  Future<bool> killProcess(int pid) async {
    try {
      ProcessResult result;
      if (Platform.isMacOS) {
        result = await Process.run('kill', ['-9', pid.toString()]);
      } else if (Platform.isWindows) {
        result = await Process.run('taskkill', ['/F', '/PID', pid.toString()]);
      } else {
        return false;
      }
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<ProcessDetails?> getProcessDetails(int pid) async {
    try {
      if (Platform.isMacOS) {
        final result = await Process.run('ps', [
          '-p',
          pid.toString(),
          '-o',
          'user=',
          '-o',
          'ppid=',
          '-o',
          'stat=',
          '-o',
          'etime=',
          '-o',
          'command=',
        ], stdoutEncoding: latin1);
        if (result.exitCode != 0) return null;

        final line = (result.stdout as String).trim();
        if (line.isEmpty) return null;

        final parts = line.split(RegExp(r'\s+'));
        if (parts.length < 5) return null;

        return ProcessDetails(
          pid: pid,
          user: parts[0],
          parentPid: int.tryParse(parts[1]),
          status: parts[2],
          elapsedTime: parts[3],
          command: parts.sublist(4).join(' '),
        );
      } else if (Platform.isWindows) {
        final result = await Process.run('wmic', [
          'process',
          'where',
          'ProcessId=$pid',
          'get',
          'ParentProcessId,CommandLine,ExecutablePath',
          '/format:list',
        ]);
        if (result.exitCode != 0) return null;

        final values = <String, String>{};
        for (final line in (result.stdout as String).split('\n')) {
          final idx = line.indexOf('=');
          if (idx <= 0) continue;
          values[line.substring(0, idx).trim()] = line
              .substring(idx + 1)
              .trim();
        }

        final command = values['CommandLine']?.isNotEmpty == true
            ? values['CommandLine']!
            : (values['ExecutablePath'] ?? '');

        return ProcessDetails(
          pid: pid,
          parentPid: int.tryParse(values['ParentProcessId'] ?? ''),
          user: 'unknown',
          status: 'running',
          elapsedTime: 'unknown',
          command: command.isEmpty ? 'unknown' : command,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<List<PortInfo>> _getMacOSPorts() async {
    final result = await Process.run('lsof', [
      '-i',
      '-P',
      '-n',
    ], stdoutEncoding: latin1);

    if (result.exitCode != 0) {
      return [];
    }

    final lines = (result.stdout as String).split('\n');
    final ports = <PortInfo>[];
    final nameRegex = RegExp(
      r'^(\S+)\s+(\d+)\s+(\S+)\s+\S+\s+\S+\s+\S+\s+\S+\s+(TCP|UDP)\s+(.+)$',
    );

    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final match = nameRegex.firstMatch(line);
      if (match == null) continue;

      final processName = match.group(1)!;
      final pid = int.tryParse(match.group(2)!) ?? 0;
      final user = match.group(3)!;
      final protocol = match.group(4)!;
      final name = match.group(5)!;

      final parsed = _parseLsofName(name);
      if (parsed == null) continue;

      ports.add(
        PortInfo(
          protocol: protocol,
          localAddress: parsed['localAddr']!,
          localPort: parsed['localPort']!,
          remoteAddress: parsed['remoteAddr']!,
          remotePort: parsed['remotePort'],
          state: parsed['state']!,
          pid: pid,
          processName: processName,
          user: user,
          rawLine: line.trim(),
          rawEndpoint: name,
        ),
      );
    }

    return ports;
  }

  Map<String, dynamic>? _parseLsofName(String name) {
    String state = '';
    final stateMatch = RegExp(r'\((.+)\)$').firstMatch(name);
    if (stateMatch != null) {
      state = stateMatch.group(1)!;
      name = name.substring(0, stateMatch.start).trim();
    }

    String localPart = name;
    String remoteAddr = '*';
    int? remotePort;

    if (name.contains('->')) {
      final parts = name.split('->');
      localPart = parts[0].trim();
      final remotePart = parts[1].trim();
      final rp = _extractAddrPort(remotePart);
      remoteAddr = rp['addr']!;
      remotePort = rp['port'];
    }

    final lp = _extractAddrPort(localPart);
    final localAddr = lp['addr']!;
    final localPort = lp['port'];

    if (localPort == null) return null;

    return {
      'localAddr': localAddr,
      'localPort': localPort,
      'remoteAddr': remoteAddr,
      'remotePort': remotePort,
      'state': state,
    };
  }

  Map<String, dynamic> _extractAddrPort(String addr) {
    int? port;
    String host;

    if (addr.startsWith('[')) {
      final bracketEnd = addr.indexOf(']');
      host = addr.substring(0, bracketEnd + 1);
      final colonIdx = addr.indexOf(':', bracketEnd);
      if (colonIdx != -1) {
        port = int.tryParse(addr.substring(colonIdx + 1));
      }
    } else {
      final lastColon = addr.lastIndexOf(':');
      if (lastColon != -1) {
        host = addr.substring(0, lastColon);
        port = int.tryParse(addr.substring(lastColon + 1));
      } else {
        host = addr;
      }
    }

    return {'addr': host, 'port': port};
  }

  Future<List<PortInfo>> _getWindowsPorts() async {
    final netstatResult = await Process.run('netstat', ['-ano']);
    if (netstatResult.exitCode != 0) return [];

    final tasklistResult = await Process.run('tasklist', ['/FO', 'CSV', '/NH']);
    final pidNameMap = <int, String>{};

    if (tasklistResult.exitCode == 0) {
      final taskLines = (tasklistResult.stdout as String).split('\n');
      for (final line in taskLines) {
        final match = RegExp(r'^"(.+?)","(\d+)"').firstMatch(line.trim());
        if (match != null) {
          final name = match.group(1)!;
          final pid = int.tryParse(match.group(2)!) ?? 0;
          pidNameMap[pid] = name;
        }
      }
    }

    final lines = (netstatResult.stdout as String).split('\n');
    final ports = <PortInfo>[];

    for (final line in lines.skip(4)) {
      if (line.trim().isEmpty) continue;
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 5) continue;

      final proto = parts[0];
      final localAddr = parts[1];
      final remoteAddr = parts[2];

      String state = '';
      int pidIdx = 4;
      // netstat -ano for TCP shows state at index 3; for UDP it's missing
      if (parts.length >= 5 && !RegExp(r'^\d+$').hasMatch(parts[3])) {
        state = parts[3];
        pidIdx = 4;
      } else {
        pidIdx = 3;
      }

      final pidStr = parts.length > pidIdx ? parts[pidIdx] : '0';
      final pid = int.tryParse(pidStr) ?? 0;

      final lp = _extractAddrPort(localAddr);
      final localPort = lp['port'];
      if (localPort == null || localPort == 0) continue;

      final rp = _extractAddrPort(remoteAddr);

      final procName = pidNameMap[pid] ?? 'unknown';

      ports.add(
        PortInfo(
          protocol: proto,
          localAddress: lp['addr']!,
          localPort: localPort,
          remoteAddress: rp['addr']!,
          remotePort: rp['port'],
          state: state,
          pid: pid,
          processName: procName,
          rawLine: line.trim(),
          rawEndpoint: '$localAddr -> $remoteAddr',
        ),
      );
    }

    return ports;
  }
}
