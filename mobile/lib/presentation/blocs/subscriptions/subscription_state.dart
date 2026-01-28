import 'package:equatable/equatable.dart';

import '../../../data/models/subscription_model.dart';

/// Subscription states
sealed class SubscriptionState extends Equatable {
  const SubscriptionState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class SubscriptionInitial extends SubscriptionState {
  const SubscriptionInitial();
}

/// Loading subscriptions
class SubscriptionLoading extends SubscriptionState {
  const SubscriptionLoading();
}

/// Subscriptions loaded successfully
class SubscriptionLoaded extends SubscriptionState {
  final List<SubscriptionModel> subscriptions;
  final int totalCount;
  final double monthlyTotal;
  final double yearlyTotal;
  final int flaggedCount;

  const SubscriptionLoaded({
    required this.subscriptions,
    required this.totalCount,
    required this.monthlyTotal,
    required this.yearlyTotal,
    required this.flaggedCount,
  });

  @override
  List<Object?> get props => [
        subscriptions,
        totalCount,
        monthlyTotal,
        yearlyTotal,
        flaggedCount,
      ];

  SubscriptionLoaded copyWith({
    List<SubscriptionModel>? subscriptions,
    int? totalCount,
    double? monthlyTotal,
    double? yearlyTotal,
    int? flaggedCount,
  }) {
    return SubscriptionLoaded(
      subscriptions: subscriptions ?? this.subscriptions,
      totalCount: totalCount ?? this.totalCount,
      monthlyTotal: monthlyTotal ?? this.monthlyTotal,
      yearlyTotal: yearlyTotal ?? this.yearlyTotal,
      flaggedCount: flaggedCount ?? this.flaggedCount,
    );
  }
}

/// Error loading subscriptions
class SubscriptionError extends SubscriptionState {
  final String message;

  const SubscriptionError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Subscription operation in progress (create, update, delete)
class SubscriptionOperationInProgress extends SubscriptionState {
  final SubscriptionLoaded previousState;

  const SubscriptionOperationInProgress({required this.previousState});

  @override
  List<Object?> get props => [previousState];
}

/// Pro subscription required (free tier limit reached)
class SubscriptionProRequired extends SubscriptionState {
  final int currentCount;
  final int maxAllowed;
  final String message;

  const SubscriptionProRequired({
    required this.currentCount,
    required this.maxAllowed,
    required this.message,
  });

  @override
  List<Object?> get props => [currentCount, maxAllowed, message];
}

/// AI flag analysis complete
class SubscriptionAnalysisComplete extends SubscriptionState {
  final int flaggedCount;
  final String message;
  final SubscriptionLoaded previousState;

  const SubscriptionAnalysisComplete({
    required this.flaggedCount,
    required this.message,
    required this.previousState,
  });

  @override
  List<Object?> get props => [flaggedCount, message, previousState];
}

/// AI flag summary loaded
class SubscriptionFlagSummaryLoaded extends SubscriptionState {
  final AIFlagSummaryResponse summary;
  final SubscriptionLoaded? previousState;

  const SubscriptionFlagSummaryLoaded({
    required this.summary,
    this.previousState,
  });

  @override
  List<Object?> get props => [summary, previousState];
}
