class CounterModel {
  final int value;
  final List<OperationModel> history;
  final int totalIncrements;
  final int totalDecrements;

  const CounterModel({
    required this.value,
    required this.history,
    required this.totalIncrements,
    required this.totalDecrements,
  });

  factory CounterModel.initial() => const CounterModel(
        value: 0,
        history: [],
        totalIncrements: 0,
        totalDecrements: 0,
      );

  CounterModel copyWith({
    int? value,
    List<OperationModel>? history,
    int? totalIncrements,
    int? totalDecrements,
  }) {
    return CounterModel(
      value: value ?? this.value,
      history: history ?? this.history,
      totalIncrements: totalIncrements ?? this.totalIncrements,
      totalDecrements: totalDecrements ?? this.totalDecrements,
    );
  }

  Map<String, dynamic> toJson() => {
        'value': value,
        'history': history.map((e) => e.toJson()).toList(),
        'totalIncrements': totalIncrements,
        'totalDecrements': totalDecrements,
      };

  factory CounterModel.fromJson(Map<String, dynamic> json) => CounterModel(
        value: json['value'] as int? ?? 0,
        history: (json['history'] as List<dynamic>?)
                ?.whereType<Map>()
                .map((e) => OperationModel.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        totalIncrements: json['totalIncrements'] as int? ?? 0,
        totalDecrements: json['totalDecrements'] as int? ?? 0,
      );
}

class OperationModel {
  final String type;
  final int previousValue;
  final int newValue;
  final DateTime timestamp;

  const OperationModel({
    required this.type,
    required this.previousValue,
    required this.newValue,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'previousValue': previousValue,
        'newValue': newValue,
        'timestamp': timestamp.toIso8601String(),
      };

  factory OperationModel.fromJson(Map<String, dynamic> json) => OperationModel(
        type: json['type'] as String? ?? '',
        previousValue: json['previousValue'] as int? ?? 0,
        newValue: json['newValue'] as int? ?? 0,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}
