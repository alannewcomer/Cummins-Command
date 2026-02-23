import 'package:cloud_firestore/cloud_firestore.dart';

/// A single data capture at a point in time during a drive.
/// Stored as a subcollection document under a DriveSession.
class DataPoint {
  final String id;
  final int timestamp; // millis epoch

  // OBD2 / J1939 Parameters
  final double? rpm;
  final double? speed;
  final double? coolantTemp;
  final double? intakeTemp;
  final double? maf;
  final double? throttlePos;
  final double? boostPressure;
  final double? egt;
  final double? egt2;
  final double? egt3;
  final double? egt4;
  final double? transTemp;
  final double? oilTemp;
  final double? oilPressure;
  final double? engineLoad;
  final double? turboSpeed;
  final double? vgtPosition;
  final double? egrPosition;
  final double? dpfSootLoad;
  final double? dpfRegenStatus;
  final double? dpfDiffPressure;
  final double? noxPreScr;
  final double? noxPostScr;
  final double? defLevel;
  final double? defTemp;
  final double? defDosingRate;
  final double? defQuality;
  final double? railPressure;
  final double? crankcasePressure;
  final double? coolantLevel;
  final double? intercoolerOutletTemp;
  final double? exhaustBackpressure;
  final double? fuelRate;
  final double? fuelLevel;
  final double? batteryVoltage;
  final double? ambientTemp;
  final double? barometric;
  final double? odometer;
  final double? engineHours;
  final double? gearRatio;

  // New diesel-specific OBD2 parameters
  final double? accelPedalD;
  final double? demandTorque;
  final double? actualTorque;
  final double? referenceTorque;
  final double? commandedEgr;
  final double? commandedThrottle;
  final double? boostPressureCtrl;
  final double? vgtControlObd;
  final double? turboInletPressure;
  final double? turboInletTemp;
  final double? chargeAirTemp;
  final double? egtObd2;
  final double? dpfTemp;
  final double? runtimeExtended;

  // GPS
  final double? lat;
  final double? lng;
  final double? altitude;
  final double? gpsSpeed;
  final double? heading;

  // Calculated
  final double? instantMPG;
  final double? estimatedGear;
  final double? estimatedHP;
  final double? estimatedTorque;

  const DataPoint({
    required this.id,
    required this.timestamp,
    this.rpm,
    this.speed,
    this.coolantTemp,
    this.intakeTemp,
    this.maf,
    this.throttlePos,
    this.boostPressure,
    this.egt,
    this.egt2,
    this.egt3,
    this.egt4,
    this.transTemp,
    this.oilTemp,
    this.oilPressure,
    this.engineLoad,
    this.turboSpeed,
    this.vgtPosition,
    this.egrPosition,
    this.dpfSootLoad,
    this.dpfRegenStatus,
    this.dpfDiffPressure,
    this.noxPreScr,
    this.noxPostScr,
    this.defLevel,
    this.defTemp,
    this.defDosingRate,
    this.defQuality,
    this.railPressure,
    this.crankcasePressure,
    this.coolantLevel,
    this.intercoolerOutletTemp,
    this.exhaustBackpressure,
    this.fuelRate,
    this.fuelLevel,
    this.batteryVoltage,
    this.ambientTemp,
    this.barometric,
    this.odometer,
    this.engineHours,
    this.gearRatio,
    this.accelPedalD,
    this.demandTorque,
    this.actualTorque,
    this.referenceTorque,
    this.commandedEgr,
    this.commandedThrottle,
    this.boostPressureCtrl,
    this.vgtControlObd,
    this.turboInletPressure,
    this.turboInletTemp,
    this.chargeAirTemp,
    this.egtObd2,
    this.dpfTemp,
    this.runtimeExtended,
    this.lat,
    this.lng,
    this.altitude,
    this.gpsSpeed,
    this.heading,
    this.instantMPG,
    this.estimatedGear,
    this.estimatedHP,
    this.estimatedTorque,
  });

  DataPoint copyWith({
    String? id,
    int? timestamp,
    double? rpm,
    double? speed,
    double? coolantTemp,
    double? intakeTemp,
    double? maf,
    double? throttlePos,
    double? boostPressure,
    double? egt,
    double? egt2,
    double? egt3,
    double? egt4,
    double? transTemp,
    double? oilTemp,
    double? oilPressure,
    double? engineLoad,
    double? turboSpeed,
    double? vgtPosition,
    double? egrPosition,
    double? dpfSootLoad,
    double? dpfRegenStatus,
    double? dpfDiffPressure,
    double? noxPreScr,
    double? noxPostScr,
    double? defLevel,
    double? defTemp,
    double? defDosingRate,
    double? defQuality,
    double? railPressure,
    double? crankcasePressure,
    double? coolantLevel,
    double? intercoolerOutletTemp,
    double? exhaustBackpressure,
    double? fuelRate,
    double? fuelLevel,
    double? batteryVoltage,
    double? ambientTemp,
    double? barometric,
    double? odometer,
    double? engineHours,
    double? gearRatio,
    double? accelPedalD,
    double? demandTorque,
    double? actualTorque,
    double? referenceTorque,
    double? commandedEgr,
    double? commandedThrottle,
    double? boostPressureCtrl,
    double? vgtControlObd,
    double? turboInletPressure,
    double? turboInletTemp,
    double? chargeAirTemp,
    double? egtObd2,
    double? dpfTemp,
    double? runtimeExtended,
    double? lat,
    double? lng,
    double? altitude,
    double? gpsSpeed,
    double? heading,
    double? instantMPG,
    double? estimatedGear,
    double? estimatedHP,
    double? estimatedTorque,
  }) {
    return DataPoint(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      rpm: rpm ?? this.rpm,
      speed: speed ?? this.speed,
      coolantTemp: coolantTemp ?? this.coolantTemp,
      intakeTemp: intakeTemp ?? this.intakeTemp,
      maf: maf ?? this.maf,
      throttlePos: throttlePos ?? this.throttlePos,
      boostPressure: boostPressure ?? this.boostPressure,
      egt: egt ?? this.egt,
      egt2: egt2 ?? this.egt2,
      egt3: egt3 ?? this.egt3,
      egt4: egt4 ?? this.egt4,
      transTemp: transTemp ?? this.transTemp,
      oilTemp: oilTemp ?? this.oilTemp,
      oilPressure: oilPressure ?? this.oilPressure,
      engineLoad: engineLoad ?? this.engineLoad,
      turboSpeed: turboSpeed ?? this.turboSpeed,
      vgtPosition: vgtPosition ?? this.vgtPosition,
      egrPosition: egrPosition ?? this.egrPosition,
      dpfSootLoad: dpfSootLoad ?? this.dpfSootLoad,
      dpfRegenStatus: dpfRegenStatus ?? this.dpfRegenStatus,
      dpfDiffPressure: dpfDiffPressure ?? this.dpfDiffPressure,
      noxPreScr: noxPreScr ?? this.noxPreScr,
      noxPostScr: noxPostScr ?? this.noxPostScr,
      defLevel: defLevel ?? this.defLevel,
      defTemp: defTemp ?? this.defTemp,
      defDosingRate: defDosingRate ?? this.defDosingRate,
      defQuality: defQuality ?? this.defQuality,
      railPressure: railPressure ?? this.railPressure,
      crankcasePressure: crankcasePressure ?? this.crankcasePressure,
      coolantLevel: coolantLevel ?? this.coolantLevel,
      intercoolerOutletTemp: intercoolerOutletTemp ?? this.intercoolerOutletTemp,
      exhaustBackpressure: exhaustBackpressure ?? this.exhaustBackpressure,
      fuelRate: fuelRate ?? this.fuelRate,
      fuelLevel: fuelLevel ?? this.fuelLevel,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      ambientTemp: ambientTemp ?? this.ambientTemp,
      barometric: barometric ?? this.barometric,
      odometer: odometer ?? this.odometer,
      engineHours: engineHours ?? this.engineHours,
      gearRatio: gearRatio ?? this.gearRatio,
      accelPedalD: accelPedalD ?? this.accelPedalD,
      demandTorque: demandTorque ?? this.demandTorque,
      actualTorque: actualTorque ?? this.actualTorque,
      referenceTorque: referenceTorque ?? this.referenceTorque,
      commandedEgr: commandedEgr ?? this.commandedEgr,
      commandedThrottle: commandedThrottle ?? this.commandedThrottle,
      boostPressureCtrl: boostPressureCtrl ?? this.boostPressureCtrl,
      vgtControlObd: vgtControlObd ?? this.vgtControlObd,
      turboInletPressure: turboInletPressure ?? this.turboInletPressure,
      turboInletTemp: turboInletTemp ?? this.turboInletTemp,
      chargeAirTemp: chargeAirTemp ?? this.chargeAirTemp,
      egtObd2: egtObd2 ?? this.egtObd2,
      dpfTemp: dpfTemp ?? this.dpfTemp,
      runtimeExtended: runtimeExtended ?? this.runtimeExtended,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      altitude: altitude ?? this.altitude,
      gpsSpeed: gpsSpeed ?? this.gpsSpeed,
      heading: heading ?? this.heading,
      instantMPG: instantMPG ?? this.instantMPG,
      estimatedGear: estimatedGear ?? this.estimatedGear,
      estimatedHP: estimatedHP ?? this.estimatedHP,
      estimatedTorque: estimatedTorque ?? this.estimatedTorque,
    );
  }

  Map<String, dynamic> toFirestore() {
    // Only write non-null fields — keeps documents small and reduces Firestore
    // write cost. timestamp is always required.
    final m = <String, dynamic>{'timestamp': timestamp};
    void set(String k, double? v) { if (v != null) m[k] = v; }

    // OBD2 / J1939
    set('rpm', rpm);
    set('speed', speed);
    set('coolantTemp', coolantTemp);
    set('intakeTemp', intakeTemp);
    set('maf', maf);
    set('throttlePos', throttlePos);
    set('boostPressure', boostPressure);
    set('egt', egt);
    set('egt2', egt2);
    set('egt3', egt3);
    set('egt4', egt4);
    set('transTemp', transTemp);
    set('oilTemp', oilTemp);
    set('oilPressure', oilPressure);
    set('engineLoad', engineLoad);
    set('turboSpeed', turboSpeed);
    set('vgtPosition', vgtPosition);
    set('egrPosition', egrPosition);
    set('dpfSootLoad', dpfSootLoad);
    set('dpfRegenStatus', dpfRegenStatus);
    set('dpfDiffPressure', dpfDiffPressure);
    set('noxPreScr', noxPreScr);
    set('noxPostScr', noxPostScr);
    set('defLevel', defLevel);
    set('defTemp', defTemp);
    set('defDosingRate', defDosingRate);
    set('defQuality', defQuality);
    set('railPressure', railPressure);
    set('crankcasePressure', crankcasePressure);
    set('coolantLevel', coolantLevel);
    set('intercoolerOutletTemp', intercoolerOutletTemp);
    set('exhaustBackpressure', exhaustBackpressure);
    set('fuelRate', fuelRate);
    set('fuelLevel', fuelLevel);
    set('batteryVoltage', batteryVoltage);
    set('ambientTemp', ambientTemp);
    set('barometric', barometric);
    set('odometer', odometer);
    set('engineHours', engineHours);
    set('gearRatio', gearRatio);
    set('accelPedalD', accelPedalD);
    set('demandTorque', demandTorque);
    set('actualTorque', actualTorque);
    set('referenceTorque', referenceTorque);
    set('commandedEgr', commandedEgr);
    set('commandedThrottle', commandedThrottle);
    set('boostPressureCtrl', boostPressureCtrl);
    set('vgtControlObd', vgtControlObd);
    set('turboInletPressure', turboInletPressure);
    set('turboInletTemp', turboInletTemp);
    set('chargeAirTemp', chargeAirTemp);
    set('egtObd2', egtObd2);
    set('dpfTemp', dpfTemp);
    set('runtimeExtended', runtimeExtended);
    // GPS
    set('lat', lat);
    set('lng', lng);
    set('altitude', altitude);
    set('gpsSpeed', gpsSpeed);
    set('heading', heading);
    // Calculated
    set('instantMPG', instantMPG);
    set('estimatedGear', estimatedGear);
    set('estimatedHP', estimatedHP);
    set('estimatedTorque', estimatedTorque);

    return m;
  }

  factory DataPoint.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return DataPoint(
      id: doc.id,
      timestamp: (d['timestamp'] as num?)?.toInt() ?? 0,
      // OBD2 / J1939
      rpm: (d['rpm'] as num?)?.toDouble(),
      speed: (d['speed'] as num?)?.toDouble(),
      coolantTemp: (d['coolantTemp'] as num?)?.toDouble(),
      intakeTemp: (d['intakeTemp'] as num?)?.toDouble(),
      maf: (d['maf'] as num?)?.toDouble(),
      throttlePos: (d['throttlePos'] as num?)?.toDouble(),
      boostPressure: (d['boostPressure'] as num?)?.toDouble(),
      egt: (d['egt'] as num?)?.toDouble(),
      egt2: (d['egt2'] as num?)?.toDouble(),
      egt3: (d['egt3'] as num?)?.toDouble(),
      egt4: (d['egt4'] as num?)?.toDouble(),
      transTemp: (d['transTemp'] as num?)?.toDouble(),
      oilTemp: (d['oilTemp'] as num?)?.toDouble(),
      oilPressure: (d['oilPressure'] as num?)?.toDouble(),
      engineLoad: (d['engineLoad'] as num?)?.toDouble(),
      turboSpeed: (d['turboSpeed'] as num?)?.toDouble(),
      vgtPosition: (d['vgtPosition'] as num?)?.toDouble(),
      egrPosition: (d['egrPosition'] as num?)?.toDouble(),
      dpfSootLoad: (d['dpfSootLoad'] as num?)?.toDouble(),
      dpfRegenStatus: (d['dpfRegenStatus'] as num?)?.toDouble(),
      dpfDiffPressure: (d['dpfDiffPressure'] as num?)?.toDouble(),
      noxPreScr: (d['noxPreScr'] as num?)?.toDouble(),
      noxPostScr: (d['noxPostScr'] as num?)?.toDouble(),
      defLevel: (d['defLevel'] as num?)?.toDouble(),
      defTemp: (d['defTemp'] as num?)?.toDouble(),
      defDosingRate: (d['defDosingRate'] as num?)?.toDouble(),
      defQuality: (d['defQuality'] as num?)?.toDouble(),
      railPressure: (d['railPressure'] as num?)?.toDouble(),
      crankcasePressure: (d['crankcasePressure'] as num?)?.toDouble(),
      coolantLevel: (d['coolantLevel'] as num?)?.toDouble(),
      intercoolerOutletTemp: (d['intercoolerOutletTemp'] as num?)?.toDouble(),
      exhaustBackpressure: (d['exhaustBackpressure'] as num?)?.toDouble(),
      fuelRate: (d['fuelRate'] as num?)?.toDouble(),
      fuelLevel: (d['fuelLevel'] as num?)?.toDouble(),
      batteryVoltage: (d['batteryVoltage'] as num?)?.toDouble(),
      ambientTemp: (d['ambientTemp'] as num?)?.toDouble(),
      barometric: (d['barometric'] as num?)?.toDouble(),
      odometer: (d['odometer'] as num?)?.toDouble(),
      engineHours: (d['engineHours'] as num?)?.toDouble(),
      gearRatio: (d['gearRatio'] as num?)?.toDouble(),
      accelPedalD: (d['accelPedalD'] as num?)?.toDouble(),
      demandTorque: (d['demandTorque'] as num?)?.toDouble(),
      actualTorque: (d['actualTorque'] as num?)?.toDouble(),
      referenceTorque: (d['referenceTorque'] as num?)?.toDouble(),
      commandedEgr: (d['commandedEgr'] as num?)?.toDouble(),
      commandedThrottle: (d['commandedThrottle'] as num?)?.toDouble(),
      boostPressureCtrl: (d['boostPressureCtrl'] as num?)?.toDouble(),
      vgtControlObd: (d['vgtControlObd'] as num?)?.toDouble(),
      turboInletPressure: (d['turboInletPressure'] as num?)?.toDouble(),
      turboInletTemp: (d['turboInletTemp'] as num?)?.toDouble(),
      chargeAirTemp: (d['chargeAirTemp'] as num?)?.toDouble(),
      egtObd2: (d['egtObd2'] as num?)?.toDouble(),
      dpfTemp: (d['dpfTemp'] as num?)?.toDouble(),
      runtimeExtended: (d['runtimeExtended'] as num?)?.toDouble(),
      // GPS
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      altitude: (d['altitude'] as num?)?.toDouble(),
      gpsSpeed: (d['gpsSpeed'] as num?)?.toDouble(),
      heading: (d['heading'] as num?)?.toDouble(),
      // Calculated
      instantMPG: (d['instantMPG'] as num?)?.toDouble(),
      estimatedGear: (d['estimatedGear'] as num?)?.toDouble(),
      estimatedHP: (d['estimatedHP'] as num?)?.toDouble(),
      estimatedTorque: (d['estimatedTorque'] as num?)?.toDouble(),
    );
  }

  /// Create from a raw map (useful for batch parsing OBD data).
  factory DataPoint.fromMap(String id, Map<String, dynamic> d) {
    return DataPoint(
      id: id,
      timestamp: (d['timestamp'] as num?)?.toInt() ?? 0,
      rpm: (d['rpm'] as num?)?.toDouble(),
      speed: (d['speed'] as num?)?.toDouble(),
      coolantTemp: (d['coolantTemp'] as num?)?.toDouble(),
      intakeTemp: (d['intakeTemp'] as num?)?.toDouble(),
      maf: (d['maf'] as num?)?.toDouble(),
      throttlePos: (d['throttlePos'] as num?)?.toDouble(),
      boostPressure: (d['boostPressure'] as num?)?.toDouble(),
      egt: (d['egt'] as num?)?.toDouble(),
      egt2: (d['egt2'] as num?)?.toDouble(),
      egt3: (d['egt3'] as num?)?.toDouble(),
      egt4: (d['egt4'] as num?)?.toDouble(),
      transTemp: (d['transTemp'] as num?)?.toDouble(),
      oilTemp: (d['oilTemp'] as num?)?.toDouble(),
      oilPressure: (d['oilPressure'] as num?)?.toDouble(),
      engineLoad: (d['engineLoad'] as num?)?.toDouble(),
      turboSpeed: (d['turboSpeed'] as num?)?.toDouble(),
      vgtPosition: (d['vgtPosition'] as num?)?.toDouble(),
      egrPosition: (d['egrPosition'] as num?)?.toDouble(),
      dpfSootLoad: (d['dpfSootLoad'] as num?)?.toDouble(),
      dpfRegenStatus: (d['dpfRegenStatus'] as num?)?.toDouble(),
      dpfDiffPressure: (d['dpfDiffPressure'] as num?)?.toDouble(),
      noxPreScr: (d['noxPreScr'] as num?)?.toDouble(),
      noxPostScr: (d['noxPostScr'] as num?)?.toDouble(),
      defLevel: (d['defLevel'] as num?)?.toDouble(),
      defTemp: (d['defTemp'] as num?)?.toDouble(),
      defDosingRate: (d['defDosingRate'] as num?)?.toDouble(),
      defQuality: (d['defQuality'] as num?)?.toDouble(),
      railPressure: (d['railPressure'] as num?)?.toDouble(),
      crankcasePressure: (d['crankcasePressure'] as num?)?.toDouble(),
      coolantLevel: (d['coolantLevel'] as num?)?.toDouble(),
      intercoolerOutletTemp: (d['intercoolerOutletTemp'] as num?)?.toDouble(),
      exhaustBackpressure: (d['exhaustBackpressure'] as num?)?.toDouble(),
      fuelRate: (d['fuelRate'] as num?)?.toDouble(),
      fuelLevel: (d['fuelLevel'] as num?)?.toDouble(),
      batteryVoltage: (d['batteryVoltage'] as num?)?.toDouble(),
      ambientTemp: (d['ambientTemp'] as num?)?.toDouble(),
      barometric: (d['barometric'] as num?)?.toDouble(),
      odometer: (d['odometer'] as num?)?.toDouble(),
      engineHours: (d['engineHours'] as num?)?.toDouble(),
      gearRatio: (d['gearRatio'] as num?)?.toDouble(),
      accelPedalD: (d['accelPedalD'] as num?)?.toDouble(),
      demandTorque: (d['demandTorque'] as num?)?.toDouble(),
      actualTorque: (d['actualTorque'] as num?)?.toDouble(),
      referenceTorque: (d['referenceTorque'] as num?)?.toDouble(),
      commandedEgr: (d['commandedEgr'] as num?)?.toDouble(),
      commandedThrottle: (d['commandedThrottle'] as num?)?.toDouble(),
      boostPressureCtrl: (d['boostPressureCtrl'] as num?)?.toDouble(),
      vgtControlObd: (d['vgtControlObd'] as num?)?.toDouble(),
      turboInletPressure: (d['turboInletPressure'] as num?)?.toDouble(),
      turboInletTemp: (d['turboInletTemp'] as num?)?.toDouble(),
      chargeAirTemp: (d['chargeAirTemp'] as num?)?.toDouble(),
      egtObd2: (d['egtObd2'] as num?)?.toDouble(),
      dpfTemp: (d['dpfTemp'] as num?)?.toDouble(),
      runtimeExtended: (d['runtimeExtended'] as num?)?.toDouble(),
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      altitude: (d['altitude'] as num?)?.toDouble(),
      gpsSpeed: (d['gpsSpeed'] as num?)?.toDouble(),
      heading: (d['heading'] as num?)?.toDouble(),
      instantMPG: (d['instantMPG'] as num?)?.toDouble(),
      estimatedGear: (d['estimatedGear'] as num?)?.toDouble(),
      estimatedHP: (d['estimatedHP'] as num?)?.toDouble(),
      estimatedTorque: (d['estimatedTorque'] as num?)?.toDouble(),
    );
  }
}
