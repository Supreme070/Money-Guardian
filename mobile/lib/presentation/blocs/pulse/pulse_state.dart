import 'package:equatable/equatable.dart';

import '../../../data/models/pulse_model.dart';

/// Pulse states
sealed class PulseState extends Equatable {
  const PulseState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class PulseInitial extends PulseState {
  const PulseInitial();
}

/// Loading pulse data
class PulseLoading extends PulseState {
  const PulseLoading();
}

/// Pulse loaded successfully
class PulseLoaded extends PulseState {
  final PulseResponse pulse;

  const PulseLoaded({required this.pulse});

  @override
  List<Object?> get props => [pulse];
}

/// Error loading pulse
class PulseError extends PulseState {
  final String message;

  const PulseError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Refreshing pulse (shows old data while refreshing)
class PulseRefreshing extends PulseState {
  final PulseResponse previousPulse;

  const PulseRefreshing({required this.previousPulse});

  @override
  List<Object?> get props => [previousPulse];
}
