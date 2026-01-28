import 'package:equatable/equatable.dart';

import '../../../data/models/alert_model.dart';

/// Alert states
sealed class AlertState extends Equatable {
  const AlertState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class AlertInitial extends AlertState {
  const AlertInitial();
}

/// Loading alerts
class AlertLoading extends AlertState {
  const AlertLoading();
}

/// Alerts loaded successfully
class AlertLoaded extends AlertState {
  final List<AlertModel> alerts;
  final int totalCount;
  final int unreadCount;
  final int criticalCount;

  const AlertLoaded({
    required this.alerts,
    required this.totalCount,
    required this.unreadCount,
    required this.criticalCount,
  });

  @override
  List<Object?> get props => [alerts, totalCount, unreadCount, criticalCount];

  AlertLoaded copyWith({
    List<AlertModel>? alerts,
    int? totalCount,
    int? unreadCount,
    int? criticalCount,
  }) {
    return AlertLoaded(
      alerts: alerts ?? this.alerts,
      totalCount: totalCount ?? this.totalCount,
      unreadCount: unreadCount ?? this.unreadCount,
      criticalCount: criticalCount ?? this.criticalCount,
    );
  }
}

/// Error loading alerts
class AlertError extends AlertState {
  final String message;

  const AlertError({required this.message});

  @override
  List<Object?> get props => [message];
}
