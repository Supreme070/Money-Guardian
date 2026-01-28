/// Utility functions for mapping between data models and UI widget enums
/// This ensures type safety while allowing separation between data layer and UI layer

import '../../data/models/subscription_model.dart' as models;
import '../../data/models/pulse_model.dart' as pulse_models;
import '../../src/widgets/subscription_card.dart' as widgets;
import '../../src/widgets/pulse_status_card.dart' as pulse_widgets;

/// Maps model AIFlag to widget SubscriptionFlag
widgets.SubscriptionFlag mapAIFlagToWidget(models.AIFlag flag) {
  switch (flag) {
    case models.AIFlag.none:
      return widgets.SubscriptionFlag.none;
    case models.AIFlag.unused:
      return widgets.SubscriptionFlag.unused;
    case models.AIFlag.duplicate:
      return widgets.SubscriptionFlag.duplicate;
    case models.AIFlag.priceIncrease:
      return widgets.SubscriptionFlag.priceIncrease;
    case models.AIFlag.trialEnding:
      return widgets.SubscriptionFlag.trialEnding;
    case models.AIFlag.forgotten:
      return widgets.SubscriptionFlag.forgotten;
  }
}

/// Maps widget SubscriptionFlag to model AIFlag
models.AIFlag mapWidgetFlagToModel(widgets.SubscriptionFlag flag) {
  switch (flag) {
    case widgets.SubscriptionFlag.none:
      return models.AIFlag.none;
    case widgets.SubscriptionFlag.unused:
      return models.AIFlag.unused;
    case widgets.SubscriptionFlag.duplicate:
      return models.AIFlag.duplicate;
    case widgets.SubscriptionFlag.priceIncrease:
      return models.AIFlag.priceIncrease;
    case widgets.SubscriptionFlag.trialEnding:
      return models.AIFlag.trialEnding;
    case widgets.SubscriptionFlag.forgotten:
      return models.AIFlag.forgotten;
  }
}

/// Maps model PulseStatus to widget PulseStatus
pulse_widgets.PulseStatus mapPulseStatusToWidget(pulse_models.PulseStatus status) {
  switch (status) {
    case pulse_models.PulseStatus.safe:
      return pulse_widgets.PulseStatus.safe;
    case pulse_models.PulseStatus.caution:
      return pulse_widgets.PulseStatus.caution;
    case pulse_models.PulseStatus.freeze:
      return pulse_widgets.PulseStatus.freeze;
  }
}

/// Maps model BillingCycle to string for display
String mapBillingCycleToString(models.BillingCycle cycle) {
  switch (cycle) {
    case models.BillingCycle.weekly:
      return 'weekly';
    case models.BillingCycle.monthly:
      return 'monthly';
    case models.BillingCycle.quarterly:
      return 'quarterly';
    case models.BillingCycle.yearly:
      return 'yearly';
  }
}

/// Parse color string from model to Color
/// Returns null if the color string is invalid or null
int? parseColorFromHex(String? hexColor) {
  if (hexColor == null || !hexColor.startsWith('#')) return null;
  try {
    return int.parse(hexColor.substring(1), radix: 16) + 0xFF000000;
  } catch (e) {
    return null;
  }
}
