// models/enums.dart
// Shared enums for the dating app

enum MessageType {
  text,
  image,
  gif,
  gift,
  audio,
  video,
  location,
  contact,
  sticker,
  emoji,
  icebreaker,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

enum GiftCategory {
  hearts,
  flowers,
  food,
  drinks,
  jewelry,
  activities,
  animals,
  seasonal,
  premium,
}

enum GiftRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

enum SubscriptionPlan {
  free,
  daily,
  weekly,
  monthly,
}

enum SubscriptionStatus {
  inactive,
  active,
  expired,
  cancelled,
  suspended,
  pending,
}
enum UserRole {
  user,
  moderator,
  admin,
  superAdmin,
}

enum ReportReason {
  fakeProfile,
  inappropriatePhotos,
  harassment,
  spam,
  underage,
  other,
}
enum SubscriptionFeature {
  unlimitedMessages,
}

// Extensions for MessageType
extension MessageTypeExtension on MessageType {
  String get displayName {
    switch (this) {
      case MessageType.text:
        return 'Text';
      case MessageType.image:
        return 'Photo';
      case MessageType.gif:
        return 'GIF';
      case MessageType.gift:
        return 'Gift';
      case MessageType.audio:
        return 'Voice Message';
      case MessageType.video:
        return 'Video';
      case MessageType.location:
        return 'Location';
      case MessageType.contact:
        return 'Contact';
      case MessageType.sticker:
        return 'Sticker';
      case MessageType.emoji:
        return 'Emoji';
      case MessageType.icebreaker:
        return 'Icebreaker';
    }
  }

  String get emoji {
    switch (this) {
      case MessageType.text:
        return '💬';
      case MessageType.image:
        return '📷';
      case MessageType.gif:
        return '🎞️';
      case MessageType.gift:
        return '🎁';
      case MessageType.audio:
        return '🎵';
      case MessageType.video:
        return '🎥';
      case MessageType.location:
        return '📍';
      case MessageType.contact:
        return '👤';
      case MessageType.sticker:
        return '😊';
      case MessageType.emoji:
        return '😀';
      case MessageType.icebreaker:
        return '❄️';
    }
  }
}

// Extensions for MessageStatus
extension MessageStatusExtension on MessageStatus {
  String get displayName {
    switch (this) {
      case MessageStatus.sending:
        return 'Sending...';
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.delivered:
        return 'Delivered';
      case MessageStatus.read:
        return 'Read';
      case MessageStatus.failed:
        return 'Failed';
    }
  }

  bool get isSuccessful {
    return this == MessageStatus.sent || 
           this == MessageStatus.delivered || 
           this == MessageStatus.read;
  }
}

// Extensions for GiftCategory
extension GiftCategoryExtension on GiftCategory {
  String get displayName {
    switch (this) {
      case GiftCategory.hearts:
        return 'Hearts & Love';
      case GiftCategory.flowers:
        return 'Flowers';
      case GiftCategory.food:
        return 'Food & Treats';
      case GiftCategory.drinks:
        return 'Drinks';
      case GiftCategory.jewelry:
        return 'Jewelry';
      case GiftCategory.activities:
        return 'Activities';
      case GiftCategory.animals:
        return 'Cute Animals';
      case GiftCategory.seasonal:
        return 'Seasonal';
      case GiftCategory.premium:
        return 'Premium';
    }
  }

  String get emoji {
    switch (this) {
      case GiftCategory.hearts:
        return '💕';
      case GiftCategory.flowers:
        return '🌹';
      case GiftCategory.food:
        return '🍰';
      case GiftCategory.drinks:
        return '🥂';
      case GiftCategory.jewelry:
        return '💍';
      case GiftCategory.activities:
        return '🎭';
      case GiftCategory.animals:
        return '🐱';
      case GiftCategory.seasonal:
        return '🎄';
      case GiftCategory.premium:
        return '💎';
    }
  }
}

// Extensions for GiftRarity
extension GiftRarityExtension on GiftRarity {
  String get displayName {
    switch (this) {
      case GiftRarity.common:
        return 'Common';
      case GiftRarity.uncommon:
        return 'Uncommon';
      case GiftRarity.rare:
        return 'Rare';
      case GiftRarity.epic:
        return 'Epic';
      case GiftRarity.legendary:
        return 'Legendary';
    }
  }

  String get emoji {
    switch (this) {
      case GiftRarity.common:
        return '⚪';
      case GiftRarity.uncommon:
        return '🟢';
      case GiftRarity.rare:
        return '🔵';
      case GiftRarity.epic:
        return '🟣';
      case GiftRarity.legendary:
        return '🟡';
    }
  }

  double get priceMultiplier {
    switch (this) {
      case GiftRarity.common:
        return 1.0;
      case GiftRarity.uncommon:
        return 1.5;
      case GiftRarity.rare:
        return 2.0;
      case GiftRarity.epic:
        return 3.0;
      case GiftRarity.legendary:
        return 5.0;
    }
  }
}

// Extensions for SubscriptionPlan
extension SubscriptionPlanExtension on SubscriptionPlan {
  String get displayName {
    switch (this) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.daily:
        return 'Daily Pass';
      case SubscriptionPlan.weekly:
        return 'Weekly Pass';
      case SubscriptionPlan.monthly:
        return 'Monthly Pass';
    }
  }

  String get description {
    switch (this) {
      case SubscriptionPlan.free:
        return 'Basic features included';
      case SubscriptionPlan.daily:
        return 'Unlimited messaging for a day';
      case SubscriptionPlan.weekly:
        return 'Unlimited messaging for a week';
      case SubscriptionPlan.monthly:
        return 'Unlimited messaging for a month';
    }
  }

  double get monthlyPrice {
    switch (this) {
      case SubscriptionPlan.free:
        return 0.0;
      case SubscriptionPlan.daily:
        return 5.49;
      case SubscriptionPlan.weekly:
        return 7.69;
      case SubscriptionPlan.monthly:
        return 11.99;
    }
  }

  List<SubscriptionFeature> get includedFeatures {
    switch (this) {
      case SubscriptionPlan.free: // can only send 4 messages to 2 users
        return [];
      case SubscriptionPlan.daily: // have access for a day/24hrs
        return [
          SubscriptionFeature.unlimitedMessages,
        ];
      case SubscriptionPlan.weekly: // have access for a week
        return [
          SubscriptionFeature.unlimitedMessages,
        ];
      case SubscriptionPlan.monthly: // have acces for a month
        return [
          SubscriptionFeature.unlimitedMessages,
        ];
    }
  }

  String get emoji {
    switch (this) {
      case SubscriptionPlan.free:
        return '🆓';
      case SubscriptionPlan.daily:
        return '☀️';
      case SubscriptionPlan.weekly:
        return '📅';
      case SubscriptionPlan.monthly:
        return '🏆';
    }
  }
}

// Extensions for SubscriptionStatus
extension SubscriptionStatusExtension on SubscriptionStatus {
  String get displayName {
    switch (this) {
      case SubscriptionStatus.inactive:
        return 'Inactive';
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.suspended:
        return 'Suspended';
      case SubscriptionStatus.pending:
        return 'Pending';
    }
  }

  bool get isValid {
    return this == SubscriptionStatus.active || this == SubscriptionStatus.pending;
  }
}

// Extensions for SubscriptionFeature
extension SubscriptionFeatureExtension on SubscriptionFeature {
  String get displayName {
    switch (this) {
      case SubscriptionFeature.unlimitedMessages:
        return 'Unlimited Messages';
    }
  }

  String get description {
    switch (this) {
      case SubscriptionFeature.unlimitedMessages:
        return 'Send as many messages as you want';
    }
  }

  String get emoji {
    switch (this) {
      case SubscriptionFeature.unlimitedMessages:
        return '💬';
    }
  }
}

// In enums.dart, fix this broken extension:
extension ReportReasonExtension on ReportReason {
  String get displayName {
    switch (this) {
      case ReportReason.fakeProfile:
        return 'Fake Profile';
      case ReportReason.inappropriatePhotos:
        return 'Inappropriate Photos';
      case ReportReason.harassment:
        return 'Harassment';
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.underage:
        return 'Underage';
      case ReportReason.other:
        return 'Other';
    }
  }
}
 