import 'package:equatable/equatable.dart';

/// Alert events
sealed class AlertEvent extends Equatable {
  const AlertEvent();

  @override
  List<Object?> get props => [];
}

/// Load all alerts
class AlertLoadRequested extends AlertEvent {
  final bool? unreadOnly;
  final String? severity;

  const AlertLoadRequested({
    this.unreadOnly,
    this.severity,
  });

  @override
  List<Object?> get props => [unreadOnly, severity];
}

/// Mark alerts as read
class AlertMarkReadRequested extends AlertEvent {
  final List<String> alertIds;

  const AlertMarkReadRequested({required this.alertIds});

  @override
  List<Object?> get props => [alertIds];
}

/// Dismiss an alert
class AlertDismissRequested extends AlertEvent {
  final String alertId;

  const AlertDismissRequested({required this.alertId});

  @override
  List<Object?> get props => [alertId];
}

/// Dismiss multiple alerts
class AlertDismissMultipleRequested extends AlertEvent {
  final List<String> alertIds;

  const AlertDismissMultipleRequested({required this.alertIds});

  @override
  List<Object?> get props => [alertIds];
}
