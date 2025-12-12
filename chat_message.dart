// lib/models/chat_message.dart
// Domain Model: ChatMessage

import 'package:intl/intl.dart';
import 'dart:convert';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? model;
  final String? imageUrl;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.model,
    this.imageUrl,
  });

  String get formattedTime => DateFormat('HH:mm').format(timestamp);

  // Helper to convert ChatMessage to API message structure (Used by AIService)
  Map<String, dynamic> toApiMessage({String? lastImageBase64}) {
    // If it's the latest user message and has an image, include the image data
    if (isUser && lastImageBase64 != null && imageUrl != null) {
      return {
        'role': 'user',
        'content': [
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,$lastImageBase64',
            }
          },
          {'type': 'text', 'text': text},
        ],
      };
    }

    // For historical messages (AI or text-only user messages)
    return {
      'role': isUser ? 'user' : 'assistant',
      'content': text,
    };
  }
}
