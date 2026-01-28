import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../core/error/exceptions.dart';
import '../../../data/repositories/subscription_repository.dart';
import 'subscription_event.dart';
import 'subscription_state.dart';

/// BLoC for subscription state management
@injectable
class SubscriptionBloc extends Bloc<SubscriptionEvent, SubscriptionState> {
  final SubscriptionRepository _subscriptionRepository;

  SubscriptionBloc(this._subscriptionRepository)
      : super(const SubscriptionInitial()) {
    on<SubscriptionLoadRequested>(_onLoadRequested);
    on<SubscriptionCreateRequested>(_onCreateRequested);
    on<SubscriptionUpdateRequested>(_onUpdateRequested);
    on<SubscriptionDeleteRequested>(_onDeleteRequested);
    on<SubscriptionPauseRequested>(_onPauseRequested);
    on<SubscriptionResumeRequested>(_onResumeRequested);
    on<SubscriptionCancelRequested>(_onCancelRequested);
    on<SubscriptionAnalyzeRequested>(_onAnalyzeRequested);
    on<SubscriptionFlagSummaryRequested>(_onFlagSummaryRequested);
  }

  Future<void> _onLoadRequested(
    SubscriptionLoadRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    emit(const SubscriptionLoading());

    try {
      final response = await _subscriptionRepository.getSubscriptions(
        isActive: event.isActive,
        aiFlag: event.aiFlag,
      );

      emit(SubscriptionLoaded(
        subscriptions: response.subscriptions,
        totalCount: response.totalCount,
        monthlyTotal: response.monthlyTotal,
        yearlyTotal: response.yearlyTotal,
        flaggedCount: response.flaggedCount,
      ));
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
    }
  }

  Future<void> _onCreateRequested(
    SubscriptionCreateRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    final currentState = state;
    if (currentState is SubscriptionLoaded) {
      emit(SubscriptionOperationInProgress(previousState: currentState));
    }

    try {
      await _subscriptionRepository.createSubscription(event.request);
      // Reload subscriptions to get updated totals
      add(const SubscriptionLoadRequested());
    } on TierLimitException catch (e) {
      // Handle tier limit exceeded
      emit(SubscriptionProRequired(
        currentCount: e.currentCount,
        maxAllowed: e.limit,
        message: e.message,
      ));
      if (currentState is SubscriptionLoaded) {
        emit(currentState);
      }
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
      if (currentState is SubscriptionLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onUpdateRequested(
    SubscriptionUpdateRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    final currentState = state;
    if (currentState is SubscriptionLoaded) {
      emit(SubscriptionOperationInProgress(previousState: currentState));
    }

    try {
      await _subscriptionRepository.updateSubscription(
        event.subscriptionId,
        event.request,
      );
      // Reload subscriptions to get updated data
      add(const SubscriptionLoadRequested());
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
      if (currentState is SubscriptionLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onDeleteRequested(
    SubscriptionDeleteRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    final currentState = state;
    if (currentState is SubscriptionLoaded) {
      emit(SubscriptionOperationInProgress(previousState: currentState));
    }

    try {
      await _subscriptionRepository.deleteSubscription(event.subscriptionId);
      // Reload subscriptions
      add(const SubscriptionLoadRequested());
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
      if (currentState is SubscriptionLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onPauseRequested(
    SubscriptionPauseRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    final currentState = state;
    if (currentState is SubscriptionLoaded) {
      emit(SubscriptionOperationInProgress(previousState: currentState));
    }

    try {
      await _subscriptionRepository.pauseSubscription(event.subscriptionId);
      add(const SubscriptionLoadRequested());
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
      if (currentState is SubscriptionLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onResumeRequested(
    SubscriptionResumeRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    final currentState = state;
    if (currentState is SubscriptionLoaded) {
      emit(SubscriptionOperationInProgress(previousState: currentState));
    }

    try {
      await _subscriptionRepository.resumeSubscription(event.subscriptionId);
      add(const SubscriptionLoadRequested());
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
      if (currentState is SubscriptionLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onCancelRequested(
    SubscriptionCancelRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    final currentState = state;
    if (currentState is SubscriptionLoaded) {
      emit(SubscriptionOperationInProgress(previousState: currentState));
    }

    try {
      await _subscriptionRepository.cancelSubscription(event.subscriptionId);
      add(const SubscriptionLoadRequested());
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
      if (currentState is SubscriptionLoaded) {
        emit(currentState);
      }
    }
  }

  Future<void> _onAnalyzeRequested(
    SubscriptionAnalyzeRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    final currentState = state;
    SubscriptionLoaded? loadedState;

    if (currentState is SubscriptionLoaded) {
      loadedState = currentState;
      emit(SubscriptionOperationInProgress(previousState: currentState));
    }

    try {
      final response = await _subscriptionRepository.analyzeSubscriptions();

      if (loadedState != null) {
        emit(SubscriptionAnalysisComplete(
          flaggedCount: response.flaggedCount,
          message: response.message,
          previousState: loadedState,
        ));
      }

      // Reload subscriptions to get updated flags
      add(const SubscriptionLoadRequested());
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
      if (loadedState != null) {
        emit(loadedState);
      }
    }
  }

  Future<void> _onFlagSummaryRequested(
    SubscriptionFlagSummaryRequested event,
    Emitter<SubscriptionState> emit,
  ) async {
    final currentState = state;
    SubscriptionLoaded? loadedState;

    if (currentState is SubscriptionLoaded) {
      loadedState = currentState;
    }

    try {
      final summary = await _subscriptionRepository.getAIFlagSummary();

      emit(SubscriptionFlagSummaryLoaded(
        summary: summary,
        previousState: loadedState,
      ));
    } catch (e) {
      emit(SubscriptionError(message: e.toString()));
      if (loadedState != null) {
        emit(loadedState);
      }
    }
  }
}
