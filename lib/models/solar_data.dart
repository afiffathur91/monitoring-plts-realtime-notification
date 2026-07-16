class SolarData {
  final double voltage;
  final double current;
  final double power;
  final DateTime timestamp;
  
  // Additional fields for PLTS monitoring
  final double? voltagePV;        // VOLT PV
  final double? voltageBattery;   // TEGANGAN BATERAI
  final double? soc;              // SOC BATERAI (%)
  final double? powerLampu;       // Watt Lampu
  final double? energy;           // Energi (Wh)

  SolarData({
    required this.voltage,
    required this.current,
    required this.power,
    required this.timestamp,
    this.voltagePV,
    this.voltageBattery,
    this.soc,
    this.powerLampu,
    this.energy,
  });

  static num _readNum(Map<String, dynamic> json, List<String> keys, {num defaultValue = 0}) {
    for (final k in keys) {
      final v = json[k];
      if (v is num) return v;
      if (v is String) {
        final parsed = num.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return defaultValue;
  }

  factory SolarData.fromJson(Map<String, dynamic> json) {
    // Robust parsing: support multiple key styles (Firebase/ESP sketch bisa beda penamaan)
    final num rawVoltage = _readNum(json, const ['Voltage', 'voltage', 'tegangan', 'Tegangan']);
    final num rawCurrent = _readNum(json, const ['Current', 'current', 'arus', 'Arus']);
    final num rawPower = _readNum(json, const ['Power', 'power', 'daya', 'Daya']);
    
    // Additional fields
    final num rawVoltagePV = _readNum(json, const ['VoltagePV', 'voltagePV', 'voltPV', 'Vpv'], defaultValue: double.nan);
    final num rawVoltageBattery = _readNum(json, const ['VoltageBattery', 'voltageBattery', 'Vbatt', 'vbatt'], defaultValue: double.nan);
    final num rawSOC = _readNum(json, const ['SOC', 'soc'], defaultValue: double.nan);
    final num rawPowerLampu = _readNum(json, const ['PowerLampu', 'powerLampu', 'wattLampu', 'WattLampu'], defaultValue: double.nan);
    final num rawEnergy = _readNum(
      json,
      const ['EnergyPV', 'Energy', 'EnergyBattery', 'energyPV', 'energy', 'energyBattery'],
      defaultValue: double.nan,
    );

    return SolarData(
      voltage: rawVoltage.toDouble(),
      current: rawCurrent.toDouble(),
      power: rawPower.toDouble(),
      timestamp: _parseTimestamp(json),
      voltagePV: rawVoltagePV.isNaN ? null : rawVoltagePV.toDouble(),
      voltageBattery: rawVoltageBattery.isNaN ? null : rawVoltageBattery.toDouble(),
      soc: rawSOC.isNaN ? null : rawSOC.toDouble(),
      powerLampu: rawPowerLampu.isNaN ? null : rawPowerLampu.toDouble(),
      energy: rawEnergy.isNaN ? null : rawEnergy.toDouble(),
    );
  }

  static DateTime _parseTimestamp(Map<String, dynamic> json) {
    final dynamic timestamp = json['timestamp'];
    if (timestamp == null) {
      return DateTime.now();
    }

    if (timestamp is int) {
      // Detect if the value is in seconds (10 digits) or milliseconds (13 digits)
      if (timestamp < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true).toLocal();
      }
      return DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true).toLocal();
    }

    if (timestamp is String) {
      final parsed = int.tryParse(timestamp);
      if (parsed != null) {
        if (parsed < 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(parsed * 1000, isUtc: true).toLocal();
        }
        return DateTime.fromMillisecondsSinceEpoch(parsed, isUtc: true).toLocal();
      }
      // If it's an ISO string, assume it's UTC unless it contains timezone offset.
      final dt = DateTime.parse(timestamp);
      return dt.isUtc ? dt.toLocal() : dt;
    }

    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'Voltage': voltage,
      'Current': current,
      'Power': power,
      'timestamp': timestamp.millisecondsSinceEpoch,
      if (voltagePV != null) 'VoltagePV': voltagePV,
      if (voltageBattery != null) 'VoltageBattery': voltageBattery,
      if (soc != null) 'SOC': soc,
      if (powerLampu != null) 'PowerLampu': powerLampu,
      if (energy != null) 'Energy': energy,
    };
  }
} 