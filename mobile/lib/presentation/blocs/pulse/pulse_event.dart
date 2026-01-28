import 'package:equatable/equatable.dart';

/// Pulse events
sealed class PulseEvent extends Equatable {
  const PulseEvent();

  @override
  List<Object?> get props => [];
}

/// Load the daily pulse
class PulseLoadRequested extends PulseEvent {
  const PulseLoadRequested();
}

/// Refresh the pulse calculation
class PulseRefreshRequested extends PulseEvent {
  const PulseRefreshRequested();
}
