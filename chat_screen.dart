// lib/screens/chat_screen.dart
// Presentation: Main chat UI and interaction handling

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/ai_service.dart';
import '../services/export_service.dart';
import '../models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  XFile? _selectedImage;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final pickedImage = await chatProvider.pickImage();
    if (pickedImage != null) {
      setState(() {
        _selectedImage = pickedImage;
      });
    }
  }

  void _sendMessage() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (_messageController.text.trim().isNotEmpty || _selectedImage != null) {
      chatProvider.sendMessage(
        _messageController.text,
        imageFile: _selectedImage,
      );
      _messageController.clear();
      setState(() {
        _selectedImage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Only allow logout if a user is actively logged in (not a guest session)
    final bool showLogout = authProvider.currentUser != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, showLogout),
            Expanded(child: _buildChatList(chatProvider)),
            if (_selectedImage != null) _buildImagePreview(),
            _buildMessageInput(chatProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool showLogout) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final isSolarFlare = themeProvider.solarFlareSelected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Model Selector
          PopupMenuButton<String>(
            onSelected: (modelId) => chatProvider.setSelectedModel(modelId),
            itemBuilder: (context) =>
                AIService.getAvailableModels().map((model) {
              return PopupMenuItem<String>(
                value: model['id'],
                child: Row(
                  children: [
                    Text(model['icon']),
                    const SizedBox(width: 12),
                    Text(model['name']),
                    if (chatProvider.selectedModel == model['id']) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.check,
                          size: 16, color: Theme.of(context).primaryColor),
                    ],
                  ],
                ),
              );
            }).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.smart_toy_outlined,
                      size: 18, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    AIService.getAvailableModels().firstWhere(
                      (model) => model['id'] == chatProvider.selectedModel,
                      orElse: () => AIService.getAvailableModels().first,
                    )['name'],
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down,
                      size: 18, color: Theme.of(context).primaryColor),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Theme Button
          IconButton(
            icon: Icon(Icons.brush_outlined,
                color: isSolarFlare ? Theme.of(context).primaryColor : null),
            onPressed: () => _showThemeDialog(context, themeProvider),
            tooltip: 'Theme Settings',
          ),
          // Export Button
          IconButton(
            icon: Icon(Icons.ios_share_outlined,
                color: isSolarFlare ? Theme.of(context).primaryColor : null),
            onPressed: () => _showExportDialog(context),
            tooltip: 'Export Chat',
          ),
          // Clear Chat Button
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: isSolarFlare ? Theme.of(context).primaryColor : null),
            onPressed: () => _showClearChatDialog(context),
            tooltip: 'Clear Chat',
          ),
          // Logout Button (Conditional)
          if (showLogout)
            IconButton(
              icon: Icon(Icons.logout_outlined,
                  color: isSolarFlare ? Theme.of(context).primaryColor : null),
              onPressed: () => _showLogoutDialog(context),
              tooltip: 'Logout',
            ),
        ],
      ),
    );
  }

  Widget _buildChatList(ChatProvider chatProvider) {
    if (chatProvider.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smart_toy_outlined,
                size: 64, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 16),
            Text(
              'Start a conversation with AI',
              style: TextStyle(
                  fontSize: 16, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a multimodal model (like GPT-4o Mini) to upload an image.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: chatProvider.scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: chatProvider.messages.length +
          (chatProvider.isLoadingResponse ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatProvider.messages.length &&
            chatProvider.isLoadingResponse) {
          return _buildLoadingMessage();
        }
        final message = chatProvider.messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final primaryColor = isUser
        ? Theme.of(context).primaryColor
        : Theme.of(context).cardTheme.color;
    final textColor =
        isUser ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color;
    final crossAxisAlignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: crossAxisAlignment,
              children: [
                if (!isUser && message.model != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.model!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                // Display Uploaded Image (FIX: Added Platform Check)
                if (message.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: kIsWeb
                        ? Container(
                            // Web placeholder to prevent crash
                            color: Colors.grey.shade300,
                            height: 150,
                            width: MediaQuery.of(context).size.width * 0.6,
                            child: const Center(
                                child: Icon(Icons.image,
                                    size: 40, color: Colors.grey)),
                          )
                        : Image.file(
                            File(message.imageUrl!),
                            width: MediaQuery.of(context).size.width * 0.6,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 50),
                          ),
                  ),
                  const SizedBox(height: 10),
                ],
                // Message Bubble
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SelectableText(
                    message.text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message.formattedTime,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.secondary),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                      bottomLeft: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Thinking...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: kIsWeb
                  ? Container(
                      color: Colors.grey.shade300,
                      height: 50,
                      width: 50,
                      child: const Center(child: Icon(Icons.image, size: 20)),
                    )
                  : Image.file(
                      File(_selectedImage!.path),
                      height: 50,
                      width: 50,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Image attached: ${_selectedImage!.name}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
            ),
            IconButton(
              icon:
                  Icon(Icons.close, color: Theme.of(context).colorScheme.error),
              onPressed: () {
                setState(() {
                  _selectedImage = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(ChatProvider chatProvider) {
    final bool isListening = chatProvider.isListening;
    final bool isLoadingResponse = chatProvider.isLoadingResponse;

    final bool isSendDisabled = isLoadingResponse ||
        (isListening) ||
        (_messageController.text.trim().isEmpty && _selectedImage == null);

    final bool isExtraInputDisabled = isLoadingResponse || isListening;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // File Upload Button
          IconButton(
            icon: Icon(Icons.attach_file,
                color: isExtraInputDisabled
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).primaryColor),
            onPressed: isExtraInputDisabled ? null : _pickImage,
            tooltip: 'Attach Image',
          ),

          // Text Field or Listening Indicator
          Expanded(
            child: isListening
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mic,
                            color: Theme.of(context).colorScheme.error,
                            size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Listening...',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ),
                  )
                : TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !isLoadingResponse,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: Theme.of(context).cardTheme.color,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty || _selectedImage != null) {
                        _sendMessage();
                      }
                    },
                  ),
          ),

          const SizedBox(width: 8),

          // Voice Input/Stop Listening/Send Button
          if (isListening)
            IconButton(
              icon:
                  Icon(Icons.stop, color: Theme.of(context).colorScheme.error),
              onPressed: chatProvider.stopListening,
              tooltip: 'Stop Voice Input',
            )
          else if (!isSendDisabled && !isLoadingResponse)
            IconButton(
              icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
              onPressed: _sendMessage,
              tooltip: 'Send Message',
            )
          else
            IconButton(
              icon: Icon(
                  _messageController.text.isEmpty && _selectedImage == null
                      ? Icons.mic_outlined
                      : Icons.send,
                  color: Theme.of(context).colorScheme.secondary),
              onPressed: _messageController.text.isEmpty &&
                      _selectedImage == null &&
                      !isLoadingResponse
                  ? () => chatProvider.startListening(
                        controller: _messageController,
                        context: context,
                      )
                  : null,
              tooltip: 'Voice Input / Send Disabled',
            ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('System Default'),
              onTap: () {
                themeProvider.setTheme(ThemeMode.system);
                Navigator.pop(context);
              },
              trailing: themeProvider.themeMode == ThemeMode.system
                  ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('Light Mode'),
              onTap: () {
                themeProvider.setTheme(ThemeMode.light);
                Navigator.pop(context);
              },
              trailing: themeProvider.themeMode == ThemeMode.light
                  ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark Mode'),
              onTap: () {
                themeProvider.setTheme(ThemeMode.dark);
                Navigator.pop(context);
              },
              trailing: themeProvider.themeMode == ThemeMode.dark
                  ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userName = authProvider.currentUser?.name ?? 'User';

    if (chatProvider.messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No messages to export'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Chat'),
        content: const Text('Choose the export format:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ExportService.exportAsTxt(
                    chatProvider.messages, userName);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat exported as TXT. Please share.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Export failed: ${e.toString().replaceAll('Exception: ', '')}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('TXT'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ExportService.exportAsPdf(
                    chatProvider.messages, userName);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat exported as PDF. Please share.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Export failed: ${e.toString().replaceAll('Exception: ', '')}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('PDF'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ExportService.exportAsJson(
                    chatProvider.messages, userName);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat exported as JSON. Please share.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Export failed: ${e.toString().replaceAll('Exception: ', '')}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('JSON'),
          ),
        ],
      ),
    );
  }

  void _showClearChatDialog(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (chatProvider.messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat is already empty'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
            'Are you sure you want to clear all messages? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              chatProvider.clearChat();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chat cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).logout();
              // InitializerScreen handles the navigation to WelcomeScreen.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
