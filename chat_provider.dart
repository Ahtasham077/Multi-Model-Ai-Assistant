// lib/providers/chat_provider.dart
// Application Logic: Chat management and AI interaction

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';

import '../models/chat_message.dart';
import '../services/ai_service.dart';

class ChatProvider with ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final Uuid _uuid = const Uuid();
  final ScrollController scrollController = ScrollController();
  String _selectedModel = 'gpt-4o-mini';
  bool _isLoadingResponse = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  final ImagePicker _picker = ImagePicker();

  List<ChatMessage> get messages => _messages;
  bool get isLoadingResponse => _isLoadingResponse;
  String get selectedModel => _selectedModel;
  bool get isListening => _isListening;

  ChatProvider() {
    _initSpeech();
    _loadSelectedModel();
  }

  Future<void> _loadSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedModel = prefs.getString('selected_model') ?? 'gpt-4o-mini';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading selected model: $e');
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize();
    } catch (e) {
      _speechEnabled = false;
      debugPrint('Speech init error: $e');
    }
  }

  Future<void> startListening({
    required TextEditingController controller,
    required BuildContext context,
  }) async {
    if (!_speechEnabled) {
      await _initSpeech();
      if (!_speechEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Speech recognition is not available or permission denied.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    try {
      _isListening = true;
      notifyListeners();

      controller.clear();

      await _speech.listen(
        onResult: (result) {
          controller.text = result.recognizedWords;
          if (result.finalResult) {
            _isListening = false;
            notifyListeners();
            if (controller.text.isNotEmpty) {
              sendMessage(controller.text);
              controller.clear();
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        onDevice: false,
      );
    } catch (e) {
      _isListening = false;
      notifyListeners();
      debugPrint('Speech listen error: $e');
    }
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Speech stop error: $e');
    }
  }

  Future<void> loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getStringList('chat_messages') ?? [];

      _messages.clear();
      for (final json in messagesJson) {
        final message = _parseMessage(json);
        if (message != null) _messages.add(message);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  ChatMessage? _parseMessage(String json) {
    try {
      final parts = json.split('|');
      // id|text|isUser|timestamp|model|imageUrl
      if (parts.length >= 4) {
        return ChatMessage(
          id: parts[0],
          text: parts[1],
          isUser: parts[2] == 'true',
          timestamp: DateTime.parse(parts[3]),
          model: parts.length > 4 ? parts[4] : null,
          imageUrl: parts.length > 5 && parts[5].isNotEmpty ? parts[5] : null,
        );
      }
    } catch (e) {
      debugPrint('Parse error: $e');
    }
    return null;
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = _messages
          .map((msg) =>
              '${msg.id}|${msg.text}|${msg.isUser}|${msg.timestamp.toIso8601String()}|${msg.model ?? ''}|${msg.imageUrl ?? ''}')
          .toList();
      await prefs.setStringList('chat_messages', messagesJson);
    } catch (e) {
      debugPrint('Error saving messages: $e');
    }
  }

  Future<void> setSelectedModel(String modelId) async {
    try {
      _selectedModel = modelId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_model', modelId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting model: $e');
    }
  }

  Future<void> sendMessage(String text, {XFile? imageFile}) async {
    if (text.trim().isEmpty && imageFile == null) return;

    // Logic for auto-switching to multimodal models
    if (imageFile != null) {
      final currentModelConfig = AIService.getAvailableModels().firstWhere(
        (m) => m['id'] == _selectedModel,
        orElse: () => AIService.getAvailableModels().first,
      );
      if (currentModelConfig['multimodal'] != true) {
        await setSelectedModel('gpt-4o-mini');
      }
    }

    if (imageFile != null && text.trim().isEmpty) {
      text = "Analyze this image and provide a concise description.";
    }

    try {
      final userMessage = ChatMessage(
        id: _uuid.v4(),
        text: text.trim(),
        isUser: true,
        timestamp: DateTime.now(),
        imageUrl: imageFile?.path,
      );

      _messages.add(userMessage);
      notifyListeners();
      _saveMessages();
      _scrollToBottom();

      _isLoadingResponse = true;
      notifyListeners();

      String? base64Image;
      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      try {
        final aiResponse = await AIService.sendMessage(
          text,
          modelId: _selectedModel,
          image: base64Image,
          history: _messages,
        );

        final aiMessage = ChatMessage(
          id: _uuid.v4(),
          text: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
          model: _getCurrentModelName(),
        );

        _messages.add(aiMessage);
      } on Exception catch (e) {
        debugPrint('AI Service Error: $e');
        final fallbackMessage = ChatMessage(
          id: _uuid.v4(),
          text:
              "I apologize, but I'm having trouble connecting right now. Error: ${e.toString().replaceAll('Exception: ', '')}",
          isUser: false,
          timestamp: DateTime.now(),
          model: 'Assistant',
        );
        _messages.add(fallbackMessage);
      }

      _isLoadingResponse = false;
      notifyListeners();
      _saveMessages();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
      _isLoadingResponse = false;
      notifyListeners();
    }
  }

  String _getCurrentModelName() {
    try {
      final modelConfig = AIService.getAvailableModels().firstWhere(
        (model) => model['id'] == _selectedModel,
        orElse: () => AIService.getAvailableModels().first,
      );
      return modelConfig['name'] as String;
    } catch (e) {
      return 'AI Assistant';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<XFile?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      return image;
    } catch (e) {
      debugPrint('Image picking error: $e');
      return null;
    }
  }

  Future<void> clearChat() async {
    try {
      _messages.clear();
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('chat_messages');
    } catch (e) {
      debugPrint('Error clearing chat: $e');
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    _speech.stop();
    super.dispose();
  }
}
