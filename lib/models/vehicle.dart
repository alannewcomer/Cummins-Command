import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String id;
  final String year;
  final String make;
  final String model;
  final String trim;
  final String vin;
  final String engine;
  final String transmissionType;
  final double currentOdometer;
  final DateTime? purchaseDate;
  final double? purchaseMileage;
  final double? towingCapacity;
  final double? payloadCapacity;
  final double? gvwr;
  final bool isActive;
  final List<VehicleMod> modHistory;
  final Map<String, double>? baselineData;

  const Vehicle({
    required this.id,
    required this.year,
    required this.make,
    required this.model,
    this.trim = '',
    this.vin = '',
    this.engine = '',
    this.transmissionType = 'Automatic',
    this.currentOdometer = 0,
    this.purchaseDate,
    this.purchaseMileage,
    this.towingCapacity,
    this.payloadCapacity,
    this.gvwr,
    this.isActive = false,
    this.modHistory = const [],
    this.baselineData,
  });

  String get displayName => '$year $make $model${trim.isNotEmpty ? ' $trim' : ''}';

  Vehicle copyWith({
    String? id,
    String? year,
    String? make,
    String? model,
    String? trim,
    String? vin,
    String? engine,
    String? transmissionType,
    double? currentOdometer,
    DateTime? purchaseDate,
    double? purchaseMileage,
    double? towingCapacity,
    double? payloadCapacity,
    double? gvwr,
    bool? isActive,
    List<VehicleMod>? modHistory,
    Map<String, double>? baselineData,
  }) {
    return Vehicle(
      id: id ?? this.id,
      year: year ?? this.year,
      make: make ?? this.make,
      model: model ?? this.model,
      trim: trim ?? this.trim,
      vin: vin ?? this.vin,
      engine: engine ?? this.engine,
      transmissionType: transmissionType ?? this.transmissionType,
      currentOdometer: currentOdometer ?? this.currentOdometer,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchaseMileage: purchaseMileage ?? this.purchaseMileage,
      towingCapacity: towingCapacity ?? this.towingCapacity,
      payloadCapacity: payloadCapacity ?? this.payloadCapacity,
      gvwr: gvwr ?? this.gvwr,
      isActive: isActive ?? this.isActive,
      modHistory: modHistory ?? this.modHistory,
      baselineData: baselineData ?? this.baselineData,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'year': year,
      'make': make,
      'model': model,
      'trim': trim,
      'vin': vin,
      'engine': engine,
      'transmissionType': transmissionType,
      'currentOdometer': currentOdometer,
      'purchaseDate': purchaseDate != null ? Timestamp.fromDate(purchaseDate!) : null,
      'purchaseMileage': purchaseMileage,
      'towingCapacity': towingCapacity,
      'payloadCapacity': payloadCapacity,
      'gvwr': gvwr,
      'isActive': isActive,
      'modHistory': modHistory.map((m) => m.toMap()).toList(),
      'baselineData': baselineData,
    };
  }

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Vehicle(
      id: doc.id,
      year: data['year'] as String? ?? '',
      make: data['make'] as String? ?? '',
      model: data['model'] as String? ?? '',
      trim: data['trim'] as String? ?? '',
      vin: data['vin'] as String? ?? '',
      engine: data['engine'] as String? ?? '',
      transmissionType: data['transmissionType'] as String? ?? 'Automatic',
      currentOdometer: (data['currentOdometer'] as num?)?.toDouble() ?? 0,
      purchaseDate: (data['purchaseDate'] as Timestamp?)?.toDate(),
      purchaseMileage: (data['purchaseMileage'] as num?)?.toDouble(),
      towingCapacity: (data['towingCapacity'] as num?)?.toDouble(),
      payloadCapacity: (data['payloadCapacity'] as num?)?.toDouble(),
      gvwr: (data['gvwr'] as num?)?.toDouble(),
      isActive: data['isActive'] as bool? ?? false,
      modHistory: (data['modHistory'] as List<dynamic>?)
              ?.map((m) => VehicleMod.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      baselineData: (data['baselineData'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toDouble())),
    );
  }
}

class VehicleMod {
  final String name;
  final String description;
  final DateTime date;

  const VehicleMod({
    required this.name,
    this.description = '',
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'date': Timestamp.fromDate(date),
      };

  factory VehicleMod.fromMap(Map<String, dynamic> map) => VehicleMod(
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
