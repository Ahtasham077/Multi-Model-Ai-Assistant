// lib/services/ai_service.dart
// Infrastructure: External API integration (OpenRouter)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../config/constants.dart';

class AIService {
  static const String _baseUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  static final Map<String, String> _apiKeys = {
    'openai': OPENAI_API_KEY,
    'google': GEMINI_VISION_API_KEY,
    'anthropic': ANTHROPIC_API_KEY,
    'mistralai': MISTRAL_API_KEY,
    'meta-llama': LLAMA_API_KEY,
  };

  static final Map<String, Map<String, dynamic>> _availableModels = {
    'gpt-4o-mini': {
      'provider': 'openai',
      'name': 'GPT-4o Mini (Vision)',
      'model': 'openai/gpt-4o-mini',
      'icon': '🚀',
      'multimodal': true,
    },
    'gpt-4o': {
      'provider': 'openai',
      'name': 'GPT-4o (Vision)',
      'model': 'openai/gpt-4o',
      'icon': '⚡',
      'multimodal': true,
    },
    'claude-3.5-sonnet': {
      'provider': 'anthropic',
      'name': 'Claude 3.5 Sonnet (Vision)',
      'model': 'anthropic/claude-3.5-sonnet',
      'icon': '🎭',
      'multimodal': true,
    },
    'llama-3.1': {
      'provider': 'meta-llama',
      'name': 'Llama 3.1 70B',
      'model': 'meta-llama/llama-3.1-70b-instruct',
      'icon': '🦙',
      'multimodal': false,
    },
    'mistral-large': {
      'provider': 'mistralai',
      'name': 'Mistral Large',
      'model': 'mistralai/mistral-large',
      'icon': '🌊',
      'multimodal': false,
    },
  };

  static List<Map<String, dynamic>> getAvailableModels() {
    return _availableModels.entries.map((entry) {
      return {
        'id': entry.key,
        'name': entry.value['name'],
        'provider': entry.value['provider'],
        'model': entry.value['model'],
        'icon': entry.value['icon'],
        'multimodal': entry.value['multimodal'] ?? false,
      };
    }).toList();
  }

  static Future<String> sendMessage(String message,
      {String modelId = 'gpt-4o-mini',
      String? image,
      required List<ChatMessage> history}) async {
    try {
      final modelConfig = _availableModels[modelId];
      if (modelConfig == null) throw Exception('Model not found');

      final provider = modelConfig['provider'] as String;
      final model = modelConfig['model'] as String;
      final apiKey = _apiKeys[provider];

      if (apiKey == null)
        throw Exception('API key not found for provider $provider');

      final List<Map<String, dynamic>> apiMessages = [];

      // Map historical messages (excluding the last one)
      for (int i = 0; i < history.length - 1; i++) {
        final msg = history[i];
        apiMessages.add({
          'role': msg.isUser ? 'user' : 'assistant',
          'content': msg.text,
        });
      }

      // Handle the latest user message
      final List<dynamic> lastMessageContentList = [];

      if (image != null &&
          image.isNotEmpty &&
          (modelConfig['multimodal'] == true)) {
        lastMessageContentList.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/jpeg;base64,$image',
          }
        });
      }

      if (message.isNotEmpty) {
        lastMessageContentList.add({
          'type': 'text',
          'text': message,
        });
      }

      if (lastMessageContentList.isEmpty) {
        throw Exception('Message content (text or image) cannot be empty.');
      }

      apiMessages.add({
        'role': 'user',
        'content': lastMessageContentList,
      });

      // --- API Call ---
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://aichatassistant.com',
          'X-Title': 'AI Chat Assistant',
        },
        body: json.encode({
          'model': model,
          'messages': apiMessages,
          'max_tokens': 1000,
          'temperature': 0.7,
        }),
      );

      // --- Response Handling ---
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final choices = data['choices'] as List;
        if (choices.isNotEmpty) {
          final messageContent = choices[0]['message']['content'] as String;
          return messageContent.trim();
        } else {
          throw Exception('No response from AI. Response: ${response.body}');
        }
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } on Exception {
      rethrow;
    } catch (e) {
      debugPrint('AI Service Internal Error: $e');
      throw Exception('An unknown AI service error occurred.');
    }
  }
}
