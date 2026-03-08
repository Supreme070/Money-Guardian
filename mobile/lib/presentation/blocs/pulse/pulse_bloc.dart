import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/di/injection.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/services/analytics_service.dart';
import '../../../data/repositories/pulse_repository.dart';
import 'pulse_event.dart';
import 'pulse_state.dart';

/// BLoC for daily pulse state management
@injectable
class PulseBloc extends Bloc<PulseEvent, PulseState> {
  final PulseRepository _pulseRepository;

  PulseBloc(this._pulseRepository) : super(const PulseInitial()) {
    on<PulseLoadRequested>(_onLoadRequested);
    on<PulseRefreshRequested>(_onRefreshRequested);
  }

  Future<void> _onLoadRequested(
    PulseLoadRequested event,
    Emitter<PulseState> emit,
  ) async {
    emit(const PulseLoading());

    try {
      final pulse = await _pulseRepository.getPulse();
      getIt<AnalyticsService>().logPulseViewed(status: pulse.status.name);
      emit(PulseLoaded(pulse: pulse));
    } catch (e) {
      emit(PulseError(message: sanitizeErrorMessage(e)));
    }
  }

  Future<void> _onRefreshRequested(
    PulseRefreshRequested event,
    Emitter<PulseState> emit,
  ) async {
    final currentState = state;

    // Show refreshing state with previous data if available
    if (currentState is PulseLoaded) {
      emit(PulseRefreshing(previousPulse: currentState.pulse));
    } else {
      emit(const PulseLoading());
    }

    try {
      final pulse = await _pulseRepository.refreshPulse();
      getIt<AnalyticsService>().logPulseRefreshed();
      emit(PulseLoaded(pulse: pulse));
    } catch (e) {
      emit(PulseError(message: sanitizeErrorMessage(e)));
      // Restore previous state if available
      if (currentState is PulseLoaded) {
        emit(currentState);
      }
    }
  }
}
