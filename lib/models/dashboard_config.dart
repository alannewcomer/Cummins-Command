import 'package:cloud_firestore/cloud_firestore.dart';

/// A single widget placed on a dashboard grid.
class DashboardWidget {
  final String type;
  final String param;
  final int col;
  final int row;
  final int colSpan;
  final int rowSpan;
  final Map<String, dynamic>? thresholds;
  final String? color;

  const DashboardWidget({
    required this.type,
    required this.param,
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
      col: (m['col'] as num?)?.toInt() ?? 0,
      row: (m['row'] as num?)?.toInt() ?? 0,
      colSpan: (m['colSpan'] as num?)?.toInt() ?? 1,
      rowSpan: (m['rowSpan'] as num?)?.toInt() ?? 1,
      thresholds: m['thresholds'] as Map<String, dynamic>?,
      color: m['color'] as String?,
    );
  }
}

/// Grid layout definition for a dashboard.
class DashboardLayout {
  final int columns;
  final int rows;
  final List<DashboardWidget> widgets;

  const DashboardLayout({
    this.columns = 4,
    this.rows = 6,
    this.widgets = const [],
  });

  DashboardLayout copyWith({
    int? columns,
    int? rows,
    List<DashboardWidget>? widgets,
  }) {
    return DashboardLayout(
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      widgets: widgets ?? this.widgets,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'columns': columns,
      'rows': rows,
      'widgets': widgets.map((w) => w.toMap()).toList(),
    };
  }

  factory DashboardLayout.fromMap(Map<String, dynamic> m) {
    return DashboardLayout(
      columns: (m['columns'] as num?)?.toInt() ?? 4,
      rows: (m['rows'] as num?)?.toInt() ?? 6,
      widgets: (m['widgets'] as List<dynamic>?)
              ?.map((w) => DashboardWidget.fromMap(w as Map<String, dynamic>))
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
