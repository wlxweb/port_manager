class PortInfo {
  final String protocol;
  final String localAddress;
  final int localPort;
  final String remoteAddress;
  final int? remotePort;
  final String state;
  final int pid;
  final String processName;
  final String? user;
  final String? rawLine;
  final String? rawEndpoint;

  const PortInfo({
    required this.protocol,
    required this.localAddress,
    required this.localPort,
    required this.remoteAddress,
    this.remotePort,
    required this.state,
    required this.pid,
    required this.processName,
    this.user,
    this.rawLine,
    this.rawEndpoint,
  });
}

class ProcessDetails {
  final int pid;
  final int? parentPid;
  final String user;
  final String status;
  final String elapsedTime;
  final String command;

  const ProcessDetails({
    required this.pid,
    this.parentPid,
    required this.user,
    required this.status,
    required this.elapsedTime,
    required this.command,
  });
}
