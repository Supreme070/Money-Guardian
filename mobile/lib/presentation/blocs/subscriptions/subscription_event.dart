import 'package:equatable/equatable.dart';

import '../../../data/models/subscription_model.dart';

/// Subscription events
sealed class SubscriptionEvent extends Equatable {
  const SubscriptionEvent();

  @override
  List<Object?> get props => [];
}

/// Load all subscriptions
class SubscriptionLoadRequested extends SubscriptionEvent {
  final bool? isActive;
  final String? aiFlag;

  const SubscriptionLoadRequested({
    this.isActive,
    this.aiFlag,
  });

  @override
  List<Object?> get props => [isActive, aiFlag];
}

/// Create a new subscription
class SubscriptionCreateRequested extends SubscriptionEvent {
  final SubscriptionCreateRequest request;

  const SubscriptionCreateRequested({required this.request});

  @override
  List<Object?> get props => [request];
}

/// Update an existing subscription
class SubscriptionUpdateRequested extends SubscriptionEvent {
  final String subscriptionId;
  final SubscriptionUpdateRequest request;

  const SubscriptionUpdateRequested({
    required this.subscriptionId,
    required this.request,
  });

  @override
  List<Object?> get props => [subscriptionId, request];
}

/// Delete a subscription
class SubscriptionDeleteRequested extends SubscriptionEvent {
  final String subscriptionId;

  const SubscriptionDeleteRequested({required this.subscriptionId});

  @override
  List<Object?> get props => [subscriptionId];
}

/// Pause a subscription
class SubscriptionPauseRequested extends SubscriptionEvent {
  final String subscriptionId;

  const SubscriptionPauseRequested({required this.subscriptionId});

  @override
  List<Object?> get props => [subscriptionId];
}

/// Resume a subscription
class SubscriptionResumeRequested extends SubscriptionEvent {
  final String subscriptionId;

  const SubscriptionResumeRequested({required this.subscriptionId});

  @override
  List<Object?> get props => [subscriptionId];
}

/// Cancel a subscription
class SubscriptionCancelRequested extends SubscriptionEvent {
  final String subscriptionId;

  const SubscriptionCancelRequested({required this.subscriptionId});

  @override
  List<Object?> get props => [subscriptionId];
}

/// Load subscription history (cancelled/deleted)
class SubscriptionHistoryLoadRequested extends SubscriptionEvent {
  const SubscriptionHistoryLoadRequested();
}

/// Analyze subscriptions and apply AI flags
class SubscriptionAnalyzeRequested extends SubscriptionEvent {
  const SubscriptionAnalyzeRequested();
}

/// Load AI flag summary
class SubscriptionFlagSummaryRequested extends SubscriptionEvent {
  const SubscriptionFlagSummaryRequested();
}
