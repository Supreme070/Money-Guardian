import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/di/injection.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/services/analytics_service.dart';
import '../../../data/models/alert_model.dart';
import '../../../data/repositories/alert_repository.dart';
import 'alert_event.dart';
import 'alert_state.dart';

/// BLoC for alert state management
@injectable
class AlertBloc extends Bloc<AlertEvent, AlertState> {
  final AlertRepository _alertRepository;

  AlertBloc(this._alertRepository) : super(const AlertInitial()) {
    on<AlertLoadRequested>(_onLoadRequested);
    on<AlertMarkReadRequested>(_onMarkReadRequested);
    on<AlertDismissRequested>(_onDismissRequested);
    on<AlertDismissMultipleRequested>(_onDismissMultipleRequested);
  }

  Future<void> _onLoadRequested(
    AlertLoadRequested event,
    Emitter<AlertState> emit,
  ) async {
    emit(const AlertLoading());

    try {
      final response = await _alertRepository.getAlerts(
        unreadOnly: event.unreadOnly,
        severity: event.severity,
      );

      emit(AlertLoaded(
        alerts: response.alerts,
        totalCount: response.totalCount,
        unreadCount: response.unreadCount,
        criticalCount: response.criticalCount,
      ));
    } catch (e) {
      emit(AlertError(message: sanitizeErrorMessage(e)));
    }
  }

  Future<void> _onMarkReadRequested(
    AlertMarkReadRequested event,
    Emitter<AlertState> emit,
  ) async {
    final currentState = state;
    if (currentState is! AlertLoaded) return;

    try {
      await _alertRepository.markAlertsAsRead(event.alertIds);

      // Update local state optimistically
      final updatedAlerts = currentState.alerts.map((alert) {
        if (event.alertIds.contains(alert.id)) {
          // Create a new alert with isRead = true
          return AlertModel.fromJson({
            ...alert.toJson(),
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          });
        }
        return alert;
      }).toList();

      emit(currentState.copyWith(
        alerts: updatedAlerts,
        unreadCount: currentState.unreadCount - event.alertIds.length,
      ));
    } catch (e) {
      emit(AlertError(message: sanitizeErrorMessage(e)));
      emit(currentState);
    }
  }

  Future<void> _onDismissRequested(
    AlertDismissRequested event,
    Emitter<AlertState> emit,
  ) async {
    final currentState = state;
    if (currentState is! AlertLoaded) return;

    try {
      await _alertRepository.dismissAlert(event.alertId);
      getIt<AnalyticsService>().logAlertDismissed(alertId: event.alertId);

      // Remove alert from local state
      final updatedAlerts = currentState.alerts
          .where((alert) => alert.id != event.alertId)
          .toList();

      final dismissedAlert = currentState.alerts
          .firstWhere((alert) => alert.id == event.alertId);

      emit(currentState.copyWith(
        alerts: updatedAlerts,
        totalCount: currentState.totalCount - 1,
        unreadCount: dismissedAlert.isRead
            ? currentState.unreadCount
            : currentState.unreadCount - 1,
        criticalCount: dismissedAlert.severity == AlertSeverity.critical
            ? currentState.criticalCount - 1
            : currentState.criticalCount,
      ));
    } catch (e) {
      emit(AlertError(message: sanitizeErrorMessage(e)));
      emit(currentState);
    }
  }

  Future<void> _onDismissMultipleRequested(
    AlertDismissMultipleRequested event,
    Emitter<AlertState> emit,
  ) async {
    final currentState = state;
    if (currentState is! AlertLoaded) return;

    try {
      await _alertRepository.dismissAlerts(event.alertIds);
      // Reload alerts to get accurate counts
      add(const AlertLoadRequested());
    } catch (e) {
      emit(AlertError(message: sanitizeErrorMessage(e)));
      emit(currentState);
    }
  }
}
