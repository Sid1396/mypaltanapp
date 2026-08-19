class CounterEntity {
  final int value;
  final List<OperationEntity> history;
  final int totalIncrements;
  final int totalDecrements;

  const CounterEntity({
    required this.value,
    required this.history,
    required this.totalIncrements,
    required this.totalDecrements,
  });

  int get totalOperations => totalIncrements + totalDecrements;
  bool get isPositive => value > 0;
  bool get isNegative => value < 0;
  bool get isZero => value == 0;
}

class OperationEntity {
  final String type;
  final int previousValue;
  final int newValue;
  final DateTime timestamp;

  const OperationEntity({
    required this.type,
    required this.previousValue,
    required this.newValue,
    required this.timestamp,
  });

  int get change => newValue - previousValue;
  bool get wasIncrease => change > 0;
  bool get wasDecrease => change < 0;
}
