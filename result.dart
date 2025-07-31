// models/result_models.dart
 

import 'conversation_model.dart';
import 'gift_model.dart';
import 'message_model.dart';
import 'subscription_model.dart';
import 'user_model.dart';

class Result<T> {
  final bool success;
  final T? data;
  final String? error;
  final String? errorCode;

  const Result.success(this.data) 
      : success = true, 
        error = null, 
        errorCode = null;

  const Result.error(this.error, [this.errorCode]) 
      : success = false, 
        data = null;

  bool get isSuccess => success;
  bool get isError => !success;
}

// Specific result types for services
class AuthResult extends Result<String> {
  const AuthResult.success(String userId) : super.success(userId);
  const AuthResult.error(String error, [String? errorCode]) : super.error(error, errorCode);
}

class UserResult extends Result<UserModel> {
  const UserResult.success(UserModel user) : super.success(user);
  const UserResult.error(String error, [String? errorCode]) : super.error(error, errorCode);
}

class MessageResult extends Result<MessageModel> {
  const MessageResult.success(MessageModel message) : super.success(message);
  const MessageResult.error(String error, [String? errorCode]) : super.error(error, errorCode);
}

class ConversationResult extends Result<ConversationModel> {
  const ConversationResult.success(ConversationModel conversation) : super.success(conversation);
  const ConversationResult.error(String error, [String? errorCode]) : super.error(error, errorCode);
}

class GiftResult extends Result<SentGiftModel> {
  const GiftResult.success(SentGiftModel super.gift) : super.success();
  const GiftResult.error(String super.error, [super.errorCode]) : super.error();
}

class SubscriptionResult extends Result<SubscriptionModel> {
  const SubscriptionResult.success(SubscriptionModel super.subscription) : super.success();
  const SubscriptionResult.error(String super.error, [super.errorCode]) : super.error();
}

// List results for pagination
class PaginatedResult<T> {
  final List<T> items;
  final bool hasMore;
  final String? nextPageToken;
  final int totalCount;

  const PaginatedResult({
    required this.items,
    required this.hasMore,
    this.nextPageToken,
    this.totalCount = 0,
  });
}