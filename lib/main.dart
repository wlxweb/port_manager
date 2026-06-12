import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/port_info.dart';
import 'services/port_service.dart';

void main() {
  runApp(const PortManagerApp());
}

class PortManagerApp extends StatelessWidget {
  const PortManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF2563EB);

    return MaterialApp(
      title: 'Port Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        visualDensity: VisualDensity.standard,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFFF5F5F7),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFF1F5F9)),
          ),
        ),
        dataTableTheme: const DataTableThemeData(
          headingTextStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
          dataTextStyle: TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
          dividerThickness: 0.6,
        ),
      ),
      home: const PortScreen(),
    );
  }
}

class PortScreen extends StatefulWidget {
  const PortScreen({super.key});

  @override
  State<PortScreen> createState() => _PortScreenState();
}

class _PortScreenState extends State<PortScreen> {
  final PortService _service = PortService();
  final TextEditingController _searchController = TextEditingController();

  List<PortInfo> _ports = [];
  List<PortInfo> _filtered = [];
  bool _loading = false;
  String _error = '';
  String _filterProtocol = 'All';
  Timer? _autoRefreshTimer;
  bool _autoRefresh = false;
  int _currentPage = 0;
  int _rowsPerPage = 10;

  static const double _pagePadding = 20;
  static const double _contentMaxWidth = 1120;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefresh = !_autoRefresh;
      if (_autoRefresh) {
        _autoRefreshTimer = Timer.periodic(
          const Duration(seconds: 5),
          (_) => _refresh(),
        );
      } else {
        _autoRefreshTimer?.cancel();
      }
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final ports = await _service.getPorts();
      ports.sort((a, b) => a.localPort.compareTo(b.localPort));
      setState(() {
        _ports = ports;
        _loading = false;
        _applyFilter();
      });
    } catch (e) {
      setState(() {
        _error = '获取端口信息失败: $e';
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();

    _filtered = _ports.where((port) {
      if (_filterProtocol != 'All' && port.protocol != _filterProtocol) {
        return false;
      }

      if (query.isEmpty) return true;

      return port.localPort.toString().contains(query) ||
          port.processName.toLowerCase().contains(query) ||
          port.pid.toString().contains(query) ||
          port.localAddress.toLowerCase().contains(query) ||
          port.remoteAddress.toLowerCase().contains(query);
    }).toList();
    _clampCurrentPage();
  }

  void _clampCurrentPage() {
    final totalPages = _pageCount;
    if (totalPages == 0) {
      _currentPage = 0;
      return;
    }
    if (_currentPage >= totalPages) {
      _currentPage = totalPages - 1;
    }
  }

  int get _pageCount {
    if (_filtered.isEmpty) return 0;
    return ((_filtered.length - 1) ~/ _rowsPerPage) + 1;
  }

  Future<void> _openInBrowser(PortInfo port) async {
    await _openUrl('http://localhost:${port.localPort}');
  }

  Future<void> _openUrl(String url) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', url]);
      }

      if (!mounted) return;
      _showSnack('已在浏览器打开 $url');
    } catch (_) {}
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showSnack('已复制 $label');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showPortDetails(PortInfo port) {
    final canBrowse = port.state == 'LISTEN' && port.protocol == 'TCP';
    final detailsFuture = _service.getProcessDetails(port.pid);
    final localEndpoint = '${port.localAddress}:${port.localPort}';
    final remoteEndpoint = port.remotePort != null
        ? '${port.remoteAddress}:${port.remotePort}'
        : port.remoteAddress;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          icon: const Icon(Icons.sensors_rounded),
          title: Text(
            port.processName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          content: SizedBox(
            width: 640,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 620),
              child: SingleChildScrollView(
                child: SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildProtocolChip(port.protocol),
                          _buildPortChip(port.localPort),
                          if (port.state.isNotEmpty)
                            _buildStateChip(port.state),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoSection(
                        title: '网络',
                        icon: Icons.hub_rounded,
                        rows: [
                          _InfoRow('本地端点', localEndpoint),
                          _InfoRow('远程端点', remoteEndpoint),
                          _InfoRow('协议', port.protocol),
                          _InfoRow(
                            '状态',
                            port.state.isEmpty ? '无状态' : port.state,
                          ),
                          _InfoRow(
                            '监听范围',
                            _describeBindScope(port.localAddress),
                          ),
                          _InfoRow(
                            'HTTP 地址',
                            'http://localhost:${port.localPort}',
                          ),
                          _InfoRow(
                            'HTTPS 地址',
                            'https://localhost:${port.localPort}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<ProcessDetails?>(
                        future: detailsFuture,
                        builder: (context, snapshot) {
                          final details = snapshot.data;
                          return _buildInfoSection(
                            title: '进程',
                            icon: Icons.memory_rounded,
                            rows: [
                              _InfoRow('进程名', port.processName),
                              _InfoRow('PID', port.pid.toString()),
                              _InfoRow(
                                '父进程 PID',
                                details?.parentPid?.toString() ?? '未知',
                              ),
                              _InfoRow(
                                '用户',
                                details?.user ?? port.user ?? '未知',
                              ),
                              _InfoRow('进程状态', details?.status ?? '未知'),
                              _InfoRow('运行时长', details?.elapsedTime ?? '未知'),
                              _InfoRow(
                                '启动命令',
                                snapshot.connectionState ==
                                        ConnectionState.waiting
                                    ? '正在读取...'
                                    : details?.command ?? '未获取到启动命令',
                                multiline: true,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildInfoSection(
                        title: '原始输出',
                        icon: Icons.subject_rounded,
                        rows: [
                          _InfoRow(
                            '端点文本',
                            port.rawEndpoint ??
                                '$localEndpoint -> $remoteEndpoint',
                          ),
                          _InfoRow(
                            '来源行',
                            port.rawLine ?? '无原始输出',
                            multiline: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded),
              label: const Text('复制地址'),
              onPressed: () {
                Navigator.pop(ctx);
                _copyToClipboard('localhost:${port.localPort}', '地址');
              },
            ),
            if (canBrowse)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('打开'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openInBrowser(port);
                },
              ),
            FilledButton.icon(
              icon: const Icon(Icons.close_rounded),
              label: const Text('终止'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _killProcess(port);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<_InfoRow> rows,
  }) {
    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 4),
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      collapsedShape: const Border(
        bottom: BorderSide(color: Color(0xFFE5E7EB)),
      ),
      children: rows
          .map(
            (row) =>
                _buildInfoRow(row.label, row.value, multiline: row.multiline),
          )
          .toList(),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool multiline = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              softWrap: multiline,
              overflow: multiline
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  String _describeBindScope(String address) {
    if (address == '*' ||
        address == '0.0.0.0' ||
        address == '[::]' ||
        address == '::') {
      return '所有网络接口';
    }

    if (address == '127.0.0.1' ||
        address == 'localhost' ||
        address == '[::1]' ||
        address == '::1') {
      return '仅本机';
    }

    return '指定地址';
  }

  Future<void> _killProcess(PortInfo port) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('确认终止进程'),
          content: Text(
            '${port.processName}  (PID: ${port.pid})\n端口: ${port.localPort}  (${port.protocol})\n\n系统进程可能需要管理员权限。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认终止'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await _service.killProcess(port.pid);
    if (!mounted) return;

    if (success) {
      _showSnack('已终止 ${port.processName} (PID: ${port.pid})');
      _refresh();
    } else {
      _showSnack('终止失败。如果是系统进程，可能需要 sudo 权限。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 720;
    final titleSpacing = Platform.isMacOS ? 82.0 : _pagePadding;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: titleSpacing,
        title: const Row(
          children: [
            Icon(Icons.sensors_rounded),
            SizedBox(width: 10),
            Text('Port Manager'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '自动刷新 (5s)',
            isSelected: _autoRefresh,
            selectedIcon: const Icon(Icons.sync_rounded),
            icon: const Icon(Icons.sync_outlined),
            onPressed: _toggleAutoRefresh,
          ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(isWide),
          if (_error.isNotEmpty) _buildErrorBanner(),
          _buildStatsBar(),
          Expanded(child: _loading ? _buildLoading() : _buildPortTable(isWide)),
        ],
      ),
    );
  }

  Widget _buildPageWidth(
    Widget child, {
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: child,
        ),
      ),
    );
  }

  Widget _buildToolbar(bool isWide) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
    );
    final searchBar = SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: '搜索端口 / PID / 程序名 / 地址',
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '清空搜索',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _currentPage = 0;
                      _applyFilter();
                    });
                  },
                ),
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: inputBorder.copyWith(
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.4,
            ),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
        ),
        onChanged: (_) => setState(() {
          _currentPage = 0;
          _applyFilter();
        }),
      ),
    );

    final filters = SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'All', label: Text('全部')),
        ButtonSegment(value: 'TCP', label: Text('TCP')),
        ButtonSegment(value: 'UDP', label: Text('UDP')),
      ],
      selected: {_filterProtocol},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() {
          _filterProtocol = selection.first;
          _currentPage = 0;
          _applyFilter();
        });
      },
    );

    return _buildPageWidth(
      isWide
          ? Row(
              children: [
                Expanded(child: searchBar),
                const SizedBox(width: 12),
                filters,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchBar,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: filters),
              ],
            ),
      padding: const EdgeInsets.fromLTRB(_pagePadding, 12, _pagePadding, 0),
    );
  }

  Widget _buildErrorBanner() {
    return _buildPageWidth(
      MaterialBanner(
        content: Text(_error),
        leading: const Icon(Icons.error_outline_rounded),
        actions: [
          TextButton(
            onPressed: () => setState(() => _error = ''),
            child: const Text('关闭'),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(_pagePadding, 12, _pagePadding, 0),
    );
  }

  Widget _buildStatsBar() {
    final tcpCount = _ports.where((port) => port.protocol == 'TCP').length;
    final udpCount = _ports.where((port) => port.protocol == 'UDP').length;

    return _buildPageWidth(
      Row(
        children: [
          Text(
            '${_filtered.length} 个端口',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(width: 8),
          Text(
            'TCP $tcpCount / UDP $udpCount',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (_autoRefresh) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text('自动刷新', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
      padding: const EdgeInsets.fromLTRB(_pagePadding, 16, _pagePadding, 8),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在扫描端口...'),
        ],
      ),
    );
  }

  Widget _buildPortTable(bool isWide) {
    return _buildPageWidth(
      SizedBox.expand(
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = constraints.maxWidth < 920
                  ? 920.0
                  : constraints.maxWidth;
              final pageStart = _currentPage * _rowsPerPage;
              final pagePorts = _filtered
                  .skip(pageStart)
                  .take(_rowsPerPage)
                  .toList(growable: false);

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: DataTable(
                            columnSpacing: isWide ? 24 : 16,
                            horizontalMargin: 16,
                            dataRowMinHeight: 46,
                            dataRowMaxHeight: 46,
                            headingRowHeight: 42,
                            columns: const [
                              DataColumn(label: Text('协议')),
                              DataColumn(label: Text('进程')),
                              DataColumn(label: Text('PID')),
                              DataColumn(label: Text('端口')),
                              DataColumn(label: Text('地址')),
                              DataColumn(label: Text('状态')),
                              DataColumn(label: Text('操作')),
                            ],
                            rows: pagePorts.map((port) {
                              final canBrowse =
                                  port.state == 'LISTEN' &&
                                  port.protocol == 'TCP';
                              return _buildPortRow(port, canBrowse, isWide);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  _buildPaginationFooter(),
                ],
              );
            },
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(_pagePadding, 0, _pagePadding, 24),
    );
  }

  DataRow _buildPortRow(PortInfo port, bool canBrowse, bool isWide) {
    return DataRow(
      cells: [
        DataCell(
          _buildProtocolChip(port.protocol),
          onTap: () => _showPortDetails(port),
        ),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              port.processName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          onTap: () => _showPortDetails(port),
        ),
        DataCell(
          _buildMonoText(port.pid.toString()),
          onTap: () => _showPortDetails(port),
        ),
        DataCell(
          _buildPortChip(port.localPort),
          onTap: () => _showPortDetails(port),
        ),
        DataCell(
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWide ? 190 : 150),
            child: _buildMonoText(_formatEndpoint(port)),
          ),
          onTap: () => _showPortDetails(port),
        ),
        DataCell(
          port.state.isEmpty ? const Text('-') : _buildStateChip(port.state),
          onTap: () => _showPortDetails(port),
        ),
        DataCell(_buildRowActions(port, canBrowse)),
      ],
    );
  }

  Widget _buildPaginationFooter() {
    final totalPages = _pageCount;
    final start = _filtered.isEmpty ? 0 : _currentPage * _rowsPerPage + 1;
    final end = (_currentPage * _rowsPerPage + _rowsPerPage).clamp(
      0,
      _filtered.length,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                _filtered.isEmpty
                    ? '没有匹配的端口'
                    : '$start-$end / ${_filtered.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 24),
            Text('每页', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _rowsPerPage,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: const [10, 20, 50]
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text('$value')),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _rowsPerPage = value;
                  _currentPage = 0;
                  _applyFilter();
                });
              },
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: '第一页',
              icon: const Icon(Icons.first_page_rounded),
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: _currentPage > 0
                  ? () => setState(() => _currentPage = 0)
                  : null,
            ),
            IconButton(
              tooltip: '上一页',
              icon: const Icon(Icons.chevron_left_rounded),
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: _currentPage > 0
                  ? () => setState(() => _currentPage -= 1)
                  : null,
            ),
            SizedBox(
              width: 54,
              child: Center(
                child: Text(
                  totalPages == 0
                      ? '0 / 0'
                      : '${_currentPage + 1} / $totalPages',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            IconButton(
              tooltip: '下一页',
              icon: const Icon(Icons.chevron_right_rounded),
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: _currentPage + 1 < totalPages
                  ? () => setState(() => _currentPage += 1)
                  : null,
            ),
            IconButton(
              tooltip: '最后一页',
              icon: const Icon(Icons.last_page_rounded),
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: _currentPage + 1 < totalPages
                  ? () => setState(() => _currentPage = totalPages - 1)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowActions(PortInfo port, bool canBrowse) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '查看详情',
          icon: const Icon(Icons.info_outline_rounded),
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: () => _showPortDetails(port),
        ),
        if (canBrowse)
          IconButton(
            tooltip: '浏览器打开',
            icon: const Icon(Icons.open_in_browser_rounded),
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: () => _openInBrowser(port),
          ),
        IconButton(
          tooltip: '复制地址',
          icon: const Icon(Icons.copy_rounded),
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: () =>
              _copyToClipboard('localhost:${port.localPort}', '地址'),
        ),
        IconButton(
          tooltip: '终止进程',
          icon: const Icon(Icons.close_rounded),
          iconSize: 18,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          color: Theme.of(context).colorScheme.error,
          onPressed: () => _killProcess(port),
        ),
      ],
    );
  }

  Widget _buildProtocolChip(String protocol) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTcp = protocol == 'TCP';

    return Chip(
      label: Text(protocol),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      side: BorderSide.none,
      backgroundColor: isTcp
          ? colorScheme.primaryContainer
          : colorScheme.secondaryContainer,
      labelStyle: TextStyle(
        color: isTcp
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSecondaryContainer,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildPortChip(int port) {
    final colorScheme = Theme.of(context).colorScheme;

    return Chip(
      label: Text(port.toString()),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      side: BorderSide.none,
      backgroundColor: colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildStateChip(String state) {
    final colorScheme = Theme.of(context).colorScheme;
    final isListen = state == 'LISTEN';

    return Chip(
      avatar: Icon(
        isListen ? Icons.check_circle_rounded : Icons.radio_button_checked,
        size: 13,
      ),
      label: Text(state),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.only(left: 0, right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      side: BorderSide.none,
      backgroundColor: isListen
          ? colorScheme.tertiaryContainer
          : colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: isListen
            ? colorScheme.onTertiaryContainer
            : colorScheme.onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildMonoText(String value) {
    return Text(
      value,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'monospace',
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  String _formatEndpoint(PortInfo port) {
    if (port.remotePort == null) return port.localAddress;
    return '${port.localAddress} -> ${port.remoteAddress}:${port.remotePort}';
  }
}

class _InfoRow {
  final String label;
  final String value;
  final bool multiline;

  const _InfoRow(this.label, this.value, {this.multiline = false});
}
