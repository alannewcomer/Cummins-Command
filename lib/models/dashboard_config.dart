import 'package:cloud_firestore/cloud_firestore.dart';

/// A single widget placed on a dashboard grid.
class DashboardWidget {
  final String type;
  final String param;
  final List<String>? params; // For multi-param widgets like dataStrip
  final int col;
  final int row;
  final int colSpan;
  final int rowSpan;
  final Map<String, dynamic>? thresholds;
  final String? color;

  const DashboardWidget({
    required this.type,
    required this.param,
    this.params,
    required this.col,
    required this.row,
    this.colSpan = 1,
    this.rowSpan = 1,
    this.thresholds,
    this.color,
  });

  DashboardWidget copyWith({
    String? type,
    String? param,
    List<String>? params,
    int? col,
    int? row,
    int? colSpan,
    int? rowSpan,
    Map<String, dynamic>? thresholds,
    String? color,
  }) {
    return DashboardWidget(
      type: type ?? this.type,
      param: param ?? this.param,
      params: params ?? this.params,
      col: col ?? this.col,
      row: row ?? this.row,
      colSpan: colSpan ?? this.colSpan,
      rowSpan: rowSpan ?? this.rowSpan,
      thresholds: thresholds ?? this.thresholds,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'param': param,
      if (params != null) 'params': params,
      'col': col,
      'row': row,
      'colSpan': colSpan,
      'rowSpan': rowSpan,
      'thresholds': thresholds,
      'color': color,
    };
  }

  factory DashboardWidget.fromMap(Map<String, dynamic> m) {
    return DashboardWidget(
      type: m['type'] as String? ?? '',
      param: m['param'] as String? ?? '',
      params: (m['params'] as List<dynamic>?)?.cast<String>(),
      col: (m['col'] as num?)?.toInt() ?? 0,
      row: (m['row'] as num?)?.toInt() ?? 0,
      colSpan: (m['colSpan'] as num?)?.toInt() ?? 1,
      rowSpan: (m['rowSpan'] as num?)?.toInt() ?? 1,
      thresholds: m['thresholds'] as Map<String, dynamic>?,
      color: m['color'] as String?,
    );
  }
}

/// A single row in a row-based dashboard layout.
class DashboardRow {
  final String type; // 'widgets' or 'header'
  final double height;
  final List<DashboardWidget> widgets;
  final String? title; // For header rows

  const DashboardRow({
    this.type = 'widgets',
    required this.height,
    this.widgets = const [],
    this.title,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'height': height,
      if (title != null) 'title': title,
      'widgets': widgets.map((w) => w.toMap()).toList(),
    };
  }

  factory DashboardRow.fromMap(Map<String, dynamic> m) {
    return DashboardRow(
      type: m['type'] as String? ?? 'widgets',
      height: (m['height'] as num?)?.toDouble() ?? 80,
      title: m['title'] as String?,
      widgets: (m['widgets'] as List<dynamic>?)
              ?.map((w) => DashboardWidget.fromMap(w as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Layout definition for a dashboard (supports grid or row-based).
class DashboardLayout {
  final String layoutType; // 'grid' or 'rows'
  final int columns;
  final int rows;
  final List<DashboardWidget> widgets;
  final List<DashboardRow> rowDefs;

  const DashboardLayout({
    this.layoutType = 'grid',
    this.columns = 4,
    this.rows = 6,
    this.widgets = const [],
    this.rowDefs = const [],
  });

  DashboardLayout copyWith({
    String? layoutType,
    int? columns,
    int? rows,
    List<DashboardWidget>? widgets,
    List<DashboardRow>? rowDefs,
  }) {
    return DashboardLayout(
      layoutType: layoutType ?? this.layoutType,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      widgets: widgets ?? this.widgets,
      rowDefs: rowDefs ?? this.rowDefs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': layoutType,
      'columns': columns,
      'rows': rows,
      'widgets': widgets.map((w) => w.toMap()).toList(),
      if (rowDefs.isNotEmpty) 'rowDefs': rowDefs.map((r) => r.toMap()).toList(),
    };
  }

  factory DashboardLayout.fromMap(Map<String, dynamic> m) {
    return DashboardLayout(
      layoutType: m['type'] as String? ?? 'grid',
      columns: (m['columns'] as num?)?.toInt() ?? 4,
      rows: (m['rows'] as num?)?.toInt() ?? 6,
      widgets: (m['widgets'] as List<dynamic>?)
              ?.map((w) => DashboardWidget.fromMap(w as Map<String, dynamic>))
              .toList() ??
          [],
      rowDefs: (m['rowDefs'] as List<dynamic>?)
              ?.map((r) => DashboardRow.fromMap(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// User-configurable dashboard with a named grid layout of widgets.
class DashboardConfig {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String source; // user, ai_generated, template, community
  final String? aiPrompt;
  final DashboardLayout layout;

  const DashboardConfig({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.source = 'user',
    this.aiPrompt,
    this.layout = const DashboardLayout(),
  });

  DashboardConfig copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? source,
    String? aiPrompt,
    DashboardLayout? layout,
  }) {
    return DashboardConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      source: source ?? this.source,
      aiPrompt: aiPrompt ?? this.aiPrompt,
      layout: layout ?? this.layout,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'source': source,
      'aiPrompt': aiPrompt,
      'layout': layout.toMap(),
    };
  }

  factory DashboardConfig.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return DashboardConfig(
      id: doc.id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String?,
      icon: d['icon'] as String?,
      source: d['source'] as String? ?? 'user',
      aiPrompt: d['aiPrompt'] as String?,
      layout: d['layout'] != null
          ? DashboardLayout.fromMap(d['layout'] as Map<String, dynamic>)
          : const DashboardLayout(),
    );
  }
}
