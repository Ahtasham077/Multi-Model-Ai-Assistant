import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'
    as fba; // ALIASING for User class clarity
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

// Helper for firstWhereOrNull equivalent
extension IterableExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

// IMPORTANT: REPLACE THESE PUBLIC KEYS WITH YOUR PRIVATE OPENROUTER KEYS.
const String GEMINI_VISION_API_KEY =
    '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';
const String OPENAI_API_KEY =
    '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';
const String ANTHROPIC_API_KEY =
    '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';
const String MISTRAL_API_KEY =
    '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';
const String LLAMA_API_KEY =
    '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';
// END API KEY DEFINITIONS

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          ThemeData selectedTheme;

          if (themeProvider.themeMode == ThemeMode.dark) {
            selectedTheme = themeProvider.darkTheme;
          } else {
            selectedTheme = themeProvider.lightTheme;
          }

          return MaterialApp(
            title: 'AI Chat Assistant',
            debugShowCheckedModeBanner: false,
            theme: selectedTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const InitializerScreen(),
          );
        },
      ),
    );
  }
}

// ==================== INITIALIZER SCREEN ====================

class InitializerScreen extends StatefulWidget {
  const InitializerScreen({super.key});

  @override
  State<InitializerScreen> createState() => _InitializerScreenState();
}

class _InitializerScreenState extends State<InitializerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      await themeProvider.loadTheme();
      await authProvider.checkLoginStatus();

      // Load messages (and sessions)
      await chatProvider.loadMessages();
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          // Existing Loading screen
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6B7280),
                    Color(0xFF9CA3AF),
                    Color(0xFFD1D5DB)
                  ],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 24),
                    Text(
                      'AI Chat Assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Loading...',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return authProvider.isLoggedIn
            ? const ChatScreen()
            : const WelcomeScreen();
      },
    );
  }
}

// ==================== PROVIDERS ====================

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _customThemeKey = 'system';
  static const String _themeKey = 'theme_mode';

  ThemeMode get themeMode => _themeMode;
  bool get solarFlareSelected => false;

  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString(_themeKey);

      if (theme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (theme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> setTheme(ThemeMode mode, {bool isSolarFlare = false}) async {
    try {
      _themeMode = mode;
      String key = mode.toString().split('.').last;

      if (mode == ThemeMode.dark) {
        key = 'dark';
      }
      _customThemeKey = key;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, key);
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting theme: $e');
    }
  }

  ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        primaryColor: const Color(0xFF6B7280),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF6B7280),
          secondary: Color(0xFF9CA3AF),
          surface: Colors.white,
          error: Color(0xFFEF4444),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF1E293B),
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
        ),
      );

  ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF6B7280),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6B7280),
          secondary: Color(0xFF9CA3AF),
          surface: Color(0xFF1E293B),
          error: Color(0xFFFCA5A5),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF1E293B),
        ),
      );
}

class AuthProvider with ChangeNotifier {
  final fba.FirebaseAuth _auth = fba.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoggedIn = false;
  bool _isLoading = true;
  User? _currentUser;
  final Uuid _uuid = const Uuid();

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  User? get currentUser => _currentUser;

  Future<void> checkLoginStatus() async {
    try {
      final firebaseUser = _auth.currentUser;

      if (firebaseUser != null) {
        _currentUser = User(
          id: firebaseUser.uid,
          email: firebaseUser.email!,
          name: firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
          createdAt: DateTime.now(),
        );
        _isLoggedIn = true;
      } else {
        final prefs = await SharedPreferences.getInstance();
        final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

        if (isLoggedIn) {
          final email = prefs.getString('user_email');
          final name = prefs.getString('user_name');
          final userId = prefs.getString('user_id');
          final createdAt = prefs.getString('user_createdAt');

          if (email != null && name != null) {
            _currentUser = User(
              id: userId ?? _uuid.v4(),
              email: email,
              name: name,
              createdAt: createdAt != null
                  ? DateTime.parse(createdAt)
                  : DateTime.now(),
            );
            _isLoggedIn = true;
          }
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking login: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    try {
      _isLoading = true;
      notifyListeners();

      final fba.UserCredential result =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      await result.user!.updateDisplayName(name);

      await _saveLocalUser(result.user!);

      _currentUser = User(
        id: result.user!.uid,
        email: email,
        name: name,
        createdAt: DateTime.now(),
      );

      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final fba.UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      await _saveLocalUser(result.user!);

      _currentUser = User(
        id: result.user!.uid,
        email: email,
        name: result.user!.displayName ?? result.user!.email!.split('@')[0],
        createdAt: DateTime.now(),
      );

      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final fba.AuthCredential credential = fba.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final fba.UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      final displayName = userCredential.user!.displayName ??
          userCredential.user!.email!.split('@')[0];

      if (userCredential.user!.displayName == null) {
        await userCredential.user!.updateDisplayName(displayName);
      }

      await _saveLocalUser(userCredential.user!);

      _currentUser = User(
        id: userCredential.user!.uid,
        email: userCredential.user!.email!,
        name: displayName,
        createdAt: DateTime.now(),
      );

      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);

      _isLoggedIn = false;
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error logging out: $e');
    }
  }

  Future<void> _saveLocalUser(fba.User firebaseUser) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('user_id', firebaseUser.uid);
    await prefs.setString('user_email', firebaseUser.email!);
    await prefs.setString('user_name',
        firebaseUser.displayName ?? firebaseUser.email!.split('@')[0]);
    await prefs.setString('user_createdAt', DateTime.now().toIso8601String());
  }
}

class ChatProvider with ChangeNotifier {
  // --- MULTI-THREAD MODE: Sessions re-introduced ---
  final List<ChatSession> _sessions = [];
  String? _currentSessionId;
  static const String _sessionKey = 'chat_sessions';

  final Map<String, List<ChatMessage>> _messageHistory = {};

  // Getters
  List<ChatMessage> get messages => _messageHistory[_currentSessionId] ?? [];
  List<ChatSession> get sessions => _sessions;
  ChatSession? get currentSession => _sessions.firstWhereOrNull(
        (s) => s.id == _currentSessionId,
      );

  // NOTE: Keep existing private fields:
  final Uuid _uuid = const Uuid();
  final ScrollController scrollController = ScrollController();
  String _selectedModel = 'gpt-4o-mini';
  bool _isLoadingResponse = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  final ImagePicker _picker = ImagePicker();

  bool get isLoadingResponse => _isLoadingResponse;
  String get selectedModel => _selectedModel;
  bool get isListening => _isListening;
  String? get currentSessionId => _currentSessionId;

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

  // --- NEW: Load all sessions and their messages ---
  Future<void> loadMessages([String? userId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load Sessions
      final sessionsJson = prefs.getStringList(_sessionKey) ?? [];
      _sessions.clear();
      for (final jsonString in sessionsJson) {
        final Map<String, dynamic> json = jsonDecode(jsonString);
        _sessions.add(ChatSession.fromJson(json));
      }

      // 2. Select Current Session
      if (_sessions.isNotEmpty) {
        _sessions.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        _currentSessionId = _sessions.first.id;
      } else {
        await createNewSession(initialTitle: "New Chat");
      }

      // 3. Load Messages for ALL sessions
      _messageHistory.clear();
      for (final session in _sessions) {
        final messagesJson =
            prefs.getStringList('messages_${session.id}') ?? [];
        _messageHistory[session.id] = [];
        for (final json in messagesJson) {
          final message = _parseMessage(json);
          if (message != null) {
            _messageHistory[session.id]!.add(message);
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  ChatMessage? _parseMessage(String json) {
    try {
      final parts = json.split('|');
      if (parts.length >= 4) {
        return ChatMessage(
          id: parts[0],
          text: parts[1],
          isUser: parts[2] == 'true',
          timestamp: DateTime.parse(parts[3]),
          model: parts.length > 4 ? parts[4] : null,
          imageUrl: parts.length > 5 && parts[5].isNotEmpty ? parts[5] : null,
          parsedContent: parts.length > 6 && parts[6].isNotEmpty
              ? jsonDecode(parts[6]) as Map<String, dynamic>?
              : null,
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

      // 1. Save all sessions
      final allSessionsJson =
          _sessions.map((s) => json.encode(s.toJson())).toList();
      await prefs.setStringList(_sessionKey, allSessionsJson);

      // 2. Save messages for each session
      for (final session in _sessions) {
        final sessionMessages = _messageHistory[session.id] ?? [];
        final messagesJson = sessionMessages
            .map((msg) =>
                '${msg.id}|${msg.text}|${msg.isUser}|${msg.timestamp.toIso8601String()}|${msg.model ?? ''}|${msg.imageUrl ?? ''}|${msg.parsedContent != null ? json.encode(msg.parsedContent) : ''}')
            .toList();
        await prefs.setStringList('messages_${session.id}', messagesJson);
      }
    } catch (e) {
      debugPrint('Error saving messages: $e');
    }
  }

  // --- NEW: Session Management Methods ---

  Future<void> createNewSession({String? initialTitle}) async {
    final newId = _uuid.v4();
    final newSession = ChatSession(
      id: newId,
      title: initialTitle ??
          'New Chat ${DateFormat('MMM d, HH:mm').format(DateTime.now())}',
      lastUpdated: DateTime.now(),
    );
    _sessions.add(newSession);
    _messageHistory[newId] = [];
    _currentSessionId = newId;

    // Sort sessions to show newest first
    _sessions.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

    await _saveMessages();
    notifyListeners();
    _scrollToBottom();
  }

  Future<void> switchSession(String sessionId) async {
    if (_currentSessionId == sessionId) return;

    _currentSessionId = sessionId;
    notifyListeners();
    _scrollToBottom();
  }

  Future<void> deleteSession(String sessionId) async {
    if (sessionId == _currentSessionId) {
      // If the current session is being deleted, switch to the newest one or create a new one
      final newSessions = _sessions.where((s) => s.id != sessionId).toList();
      if (newSessions.isNotEmpty) {
        newSessions.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        await switchSession(newSessions.first.id);
      } else {
        await createNewSession(initialTitle: "New Chat");
      }
    }

    _sessions.removeWhere((s) => s.id == sessionId);
    _messageHistory.remove(sessionId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('messages_$sessionId');

    await _saveMessages();
    notifyListeners();
  }
  // --- END Session Management Methods ---

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

  // --- UPDATED: SendMessage logic (with Session updates) ---
  Future<void> sendMessage(String text, {XFile? imageFile}) async {
    if (text.trim().isEmpty && imageFile == null) return;
    if (_currentSessionId == null) {
      await createNewSession();
    }

    final currentMessagesForHistory = messages;
    ChatMessage? userMessage;

    // --- 1. PRE-PROCESSING & MODEL ROUTING ---
    String effectiveModelId = _selectedModel;
    if (imageFile != null) {
      try {
        final currentModelConfig =
            AIService.getAvailableModels().firstWhereOrNull(
          (m) => m['id'] == _selectedModel,
        );
        if (currentModelConfig == null ||
            currentModelConfig['multimodal'] != true) {
          effectiveModelId = 'gpt-4o-mini';
          await setSelectedModel(effectiveModelId);
        }
      } catch (_) {
        effectiveModelId = 'gpt-4o-mini';
        await setSelectedModel(effectiveModelId);
      }

      if (text.trim().isEmpty) {
        text = "Analyze this image and provide a concise description.";
      }
    } else {
      effectiveModelId = AIService.getRecommendedModel(text) ?? _selectedModel;
      if (effectiveModelId != _selectedModel) {
        await setSelectedModel(effectiveModelId);
      }
    }

    try {
      // --- FIX: Read image bytes FIRST before creating message ---
      String? base64Image;
      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      userMessage = ChatMessage(
        id: _uuid.v4(),
        text: text.trim(),
        isUser: true,
        timestamp: DateTime.now(),
        imageUrl: imageFile?.path,
      );

      // Add user message to the current session's history
      _messageHistory[_currentSessionId]!.add(userMessage);

      // --- NEW: Update Session Details ---
      final currentSession = this.currentSession;
      if (currentSession != null) {
        currentSession.lastUpdated = DateTime.now();
        // If it's the first message, set the initial title placeholder
        if (_messageHistory[_currentSessionId]!.length == 1) {
          currentSession.title = "Generating Title...";
        }
      }
      // -----------------------------------

      notifyListeners();
      _saveMessages();
      _scrollToBottom();

      _isLoadingResponse = true;
      notifyListeners();

      final historyWithNewMessage = [...currentMessagesForHistory, userMessage];

      Map<String, dynamic> aiResponseData = await AIService.sendMessage(
        text,
        modelId: effectiveModelId,
        image: base64Image, // Pass the pre-encoded Base64 string
        history: historyWithNewMessage,
      );

      // --- 3. POST-PROCESSING & GENERATIVE UI ---
      String aiResponseText = aiResponseData['text'];
      Map<String, dynamic>? parsedContent;

      if (aiResponseData['isStructured']) {
        try {
          final cleanedJson = aiResponseText.substring(
              aiResponseText.indexOf('{'), aiResponseText.lastIndexOf('}') + 1);
          parsedContent = json.decode(cleanedJson) as Map<String, dynamic>;
          aiResponseText = parsedContent!['title'] ?? 'Interactive Card';
        } catch (e) {
          debugPrint('JSON parsing failed, falling back to text: $e');
          parsedContent = null;
        }
      }

      final aiMessage = ChatMessage(
        id: _uuid.v4(),
        text: aiResponseText,
        isUser: false,
        timestamp: DateTime.now(),
        model: AIService.getModelName(effectiveModelId),
        parsedContent: parsedContent,
      );

      _messageHistory[_currentSessionId]!.add(aiMessage);

      // Update session title if it was the first message
      if (currentSession != null) {
        if (_messageHistory[_currentSessionId]!.length == 2) {
          currentSession.title = await AIService.getSessionName(text);
          // Re-sort the session list to show newest first
          _sessions.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        }
      }
    } on Exception catch (e) {
      debugPrint('AI Service Error: $e');

      // Cleanup: Remove the user message if the API call failed
      if (userMessage != null) {
        _messageHistory[_currentSessionId]!
            .removeWhere((msg) => msg.id == userMessage?.id);
      }

      final fallbackMessage = ChatMessage(
        id: _uuid.v4(),
        text:
            "I apologize, but I'm having trouble connecting or processing right now. Error: ${e.toString().replaceAll('Exception: ', '')}",
        isUser: false,
        timestamp: DateTime.now(),
        model: 'Assistant',
      );
      _messageHistory[_currentSessionId]!.add(fallbackMessage);
    }

    _isLoadingResponse = false;
    notifyListeners();
    _saveMessages();
    _scrollToBottom();
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
    if (_currentSessionId != null) {
      //_messageHistory[_currentSessionId] = [];
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('messages_$_currentSessionId');

      // Reset the current session's title (optional, but good practice)
      final session = currentSession;
      if (session != null) {
        session.title = "New Chat";
        session.lastUpdated = DateTime.now();
        _saveMessages();
      }
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    _speech.stop();
    super.dispose();
  }
}

// ==================== MODELS (Simplified) ====================

class User {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
  });
}

// NOTE: ChatSession class RE-INTRODUCED for multi-thread support
class ChatSession {
  final String id;
  String title;
  DateTime lastUpdated;

  ChatSession({
    required this.id,
    required this.title,
    required this.lastUpdated,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'],
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? model;
  final String? imageUrl;
  final Map<String, dynamic>? parsedContent;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.model,
    this.imageUrl,
    this.parsedContent,
  });

  String get formattedTime => DateFormat('HH:mm').format(timestamp);
}

extension on String {
  decode(String part) {}
}

// ==================== SERVICES ====================

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
      'domain': 'general',
    },
    'gpt-4o': {
      'provider': 'openai',
      'name': 'GPT-4o (Vision)',
      'model': 'openai/gpt-4o',
      'icon': '⚡',
      'multimodal': true,
      'domain': 'complex',
    },
    'claude-3.5-sonnet': {
      'provider': 'anthropic',
      'name': 'Claude 3.5 Sonnet (Vision)',
      'model': 'anthropic/claude-3.5-sonnet',
      'icon': '🎭',
      'multimodal': true,
      'domain': 'creative',
    },
    'llama-3.1': {
      'provider': 'meta-llama',
      'name': 'Llama 3.1 70B',
      'model': 'meta-llama/llama-3.1-70b-instruct',
      'icon': '🦙',
      'multimodal': false,
      'domain': 'coding',
    },
    'mistral-large': {
      'provider': 'mistralai',
      'name': 'Mistral Large',
      'model': 'mistralai/mistral-large',
      'icon': '🌊',
      'multimodal': false,
      'domain': 'reasoning',
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

  static String getModelName(String modelId) {
    try {
      return _availableModels[modelId]?['name'] ?? 'AI Assistant';
    } catch (e) {
      return 'AI Assistant';
    }
  }

  static String? getRecommendedModel(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    if (lowerPrompt.contains('code') ||
        lowerPrompt.contains('python') ||
        lowerPrompt.contains('javascript')) {
      return 'llama-3.1';
    }
    if (lowerPrompt.contains('write a poem') ||
        lowerPrompt.contains('story') ||
        lowerPrompt.contains('creative')) {
      return 'claude-3.5-sonnet';
    }
    if (lowerPrompt.length > 500 ||
        lowerPrompt.contains('analyze') ||
        lowerPrompt.contains('evaluate')) {
      return 'gpt-4o';
    }
    return null;
  }

  // NOTE: getSessionName RE-INTRODUCED
  static Future<String> getSessionName(String firstPrompt) async {
    try {
      // Use a fast, cheap model just for title generation
      const modelId = 'gpt-4o-mini';
      final modelConfig = _availableModels[modelId];
      final provider = modelConfig?['provider'] as String;
      final model = modelConfig?['model'] as String;
      final apiKey = _apiKeys[provider];

      if (apiKey == null) return "New Chat";

      final systemPrompt =
          "You are a title generator. Summarize the following prompt into a concise chat title (max 5 words). Only return the title string, no quotes or extra text.";

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
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': firstPrompt},
          ],
          'max_tokens': 15,
          'temperature': 0.1,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        String title = content.trim().replaceAll(RegExp(r'[^\w\s\-]'), '');
        return title.isEmpty ? "New Chat" : title;
      }
      return "New Chat";
    } catch (e) {
      debugPrint('Error generating session name: $e');
      return "New Chat";
    }
  }

  static String _getSystemPrompt(String modelId) {
    String systemPrompt =
        "You are a helpful and concise assistant. Respond in clear Markdown format.";

    if (modelId == 'gpt-4o' || modelId == 'claude-3.5-sonnet') {
      systemPrompt +=
          " If the user asks for a list, a plan, or a reminder, respond with a single JSON object in the format: "
          "{\"type\": \"todo\" | \"plan\", \"title\": \"Task Title\", \"items\": [{\"text\": \"item 1\", \"done\": false}, ...]}. Otherwise, respond in standard Markdown.";
    }

    return systemPrompt;
  }

  static Future<Map<String, dynamic>> sendMessage(String message,
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

      // 1. Add System Prompt
      apiMessages.add({
        'role': 'system',
        'content': _getSystemPrompt(modelId),
      });

      // 2. Map historical messages (including the latest user message which is in history)
      for (final msg in history) {
        final content = msg.parsedContent != null
            ? "User/Assistant interaction regarding: ${msg.parsedContent!['title']}"
            : msg.text;

        // If it's the latest message (the one currently being sent) and has an image, format content for multimodal
        if (msg.isUser &&
            msg == history.last &&
            image != null &&
            image.isNotEmpty) {
          apiMessages.add({
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$image',
                }
              },
              {'type': 'text', 'text': content},
            ]
          });
        } else {
          apiMessages.add({
            'role': msg.isUser ? 'user' : 'assistant',
            'content': content,
          });
        }
      }

      // Determine if structured JSON is expected
      final bool expectsStructuredOutput =
          (modelId == 'gpt-4o' || modelId == 'claude-3.5-sonnet') &&
              (message.toLowerCase().contains('list') ||
                  message.toLowerCase().contains('plan') ||
                  message.toLowerCase().contains('remind'));

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
          return {
            'text': messageContent.trim(),
            'isStructured': expectsStructuredOutput,
          };
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

class ExportService {
  static Future<void> exportAsTxt(
      List<ChatMessage> messages, String userName, String chatTitle) async {
    try {
      final content = StringBuffer();
      content.writeln('AI Chat History - $userName | Session: $chatTitle');
      content.writeln(
          'Export Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
      content.writeln('=' * 50);
      content.writeln();

      for (final msg in messages) {
        final sender = msg.isUser ? userName : (msg.model ?? 'AI Assistant');
        content.writeln('[$sender - ${msg.formattedTime}]');
        if (msg.imageUrl != null) {
          content.writeln('[Image Attached: ${msg.imageUrl!.split('/').last}]');
        }
        content.writeln(msg.parsedContent != null
            ? '[INTERACTIVE ${msg.parsedContent!['type'].toUpperCase()}]: ${msg.parsedContent!['title']}'
            : msg.text);
        content.writeln('-' * 30);
      }

      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/chat_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(content.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'AI Chat Export - $userName',
        text:
            'Here is my AI chat export from ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      );
    } catch (e) {
      debugPrint('Export TXT error: $e');
      throw Exception('Failed to export as TXT: $e');
    }
  }

  static Future<void> exportAsPdf(
      List<ChatMessage> messages, String userName, String chatTitle) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'AI Chat History',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('User: $userName'),
                pw.Text('Chat: $chatTitle'),
                pw.Text(
                    'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
                pw.Divider(),
                pw.SizedBox(height: 20),
                ...messages.map((msg) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 15),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '${msg.isUser ? userName : (msg.model ?? 'AI Assistant')} - ${msg.formattedTime}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        if (msg.imageUrl != null)
                          pw.Text(
                            '[Image Attached: ${msg.imageUrl!.split('/').last}]',
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.blue),
                          ),
                        pw.Text(
                          msg.parsedContent != null
                              ? '[INTERACTIVE ${msg.parsedContent!['type'].toUpperCase()}]: ${msg.parsedContent!['title']}'
                              : msg.text,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Divider(),
                      ],
                    ),
                  );
                }).toList(),
              ],
            );
          },
        ),
      );

      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/chat_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'AI Chat PDF Export - $userName',
      );
    } catch (e) {
      debugPrint('Export PDF error: $e');
      throw Exception('Failed to export as PDF: $e');
    }
  }

  static Future<void> exportAsJson(
      List<ChatMessage> messages, String userName, String chatTitle) async {
    try {
      final data = {
        'user': userName,
        'chat_title': chatTitle,
        'export_date': DateTime.now().toIso8601String(),
        'message_count': messages.length,
        'messages': messages
            .map((m) => {
                  'id': m.id,
                  'text': m.text,
                  'isUser': m.isUser,
                  'timestamp': m.timestamp.toIso8601String(),
                  'model': m.model,
                  'formatted_time': m.formattedTime,
                  'imageUrl': m.imageUrl,
                  'parsedContent': m.parsedContent,
                })
            .toList(),
      };

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/chat_${DateTime.now().millisecondsSinceEpoch}.json');
      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(data));

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'AI Chat JSON Export - $userName',
      );
    } catch (e) {
      debugPrint('Export JSON error: $e');
      throw Exception('Failed to export as JSON: $e');
    }
  }
}

// ==================== WELCOME SCREEN (Unchanged) ====================

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).colorScheme.secondary,
              Theme.of(context).cardColor,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.smart_toy_outlined,
                    size: 100, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Welcome to AI Chat Assistant',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const AuthScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Sign Up or Log In',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: authProvider.isLoading
                        ? null
                        : authProvider.signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata,
                        size: 24, color: Colors.white),
                    label: const Text('Continue with Google',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // NOTE: Use of pushReplacement handles the 'Guest' session seamlessly
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (context) => const ChatScreen()));
                  },
                  child: const Text('Continue as Guest',
                      style: TextStyle(fontSize: 16, color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== AUTH SCREEN (Unchanged) ====================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (_isLogin) {
        await authProvider.login(
            _emailController.text.trim(), _passwordController.text.trim());
      } else {
        await authProvider.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _nameController.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on fba.FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getErrorMessage(dynamic e) {
    if (e is fba.FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'This email is already registered. Please sign in instead.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Password should be at least 6 characters.';
        case 'user-not-found':
          return 'No account found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'network-request-failed':
          return 'Network error. Please check your internet connection.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        default:
          return 'Authentication failed: ${e.message}';
      }
    } else if (e.toString().contains('network-request-failed')) {
      return 'Network error. Please check your internet connection.';
    } else {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.signInWithGoogle();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on fba.FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6B7280), Color(0xFF9CA3AF), Color(0xFFD1D5DB)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.smart_toy_outlined,
                      size: 80, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'AI Chat Assistant',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Powered by Multiple AI Models',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Text(
                              _isLogin ? 'Welcome Back' : 'Create Account',
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 24),
                            if (!_isLogin)
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Icon(Icons.person),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    !_isLogin && (v == null || v.isEmpty)
                                        ? 'Please enter your name'
                                        : null,
                              ),
                            if (!_isLogin) const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => v == null || !v.contains('@')
                                  ? 'Please enter a valid email'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) => v == null || v.length < 6
                                  ? 'Password must be at least 6 characters'
                                  : null,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : ElevatedButton(
                                      onPressed: _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF6B7280),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(
                                        _isLogin ? 'Sign In' : 'Create Account',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            const Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('OR'),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _isLoading ? null : _signInWithGoogle,
                                icon: const Icon(Icons.g_mobiledata, size: 24),
                                label: const Text('Continue with Google'),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(() => _isLogin = !_isLogin),
                              child: Text(
                                _isLogin
                                    ? 'Create new account'
                                    : 'Already have an account?',
                                style:
                                    const TextStyle(color: Color(0xFF6B7280)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== CHAT HISTORY DRAWER (NEW) ====================

class ChatHistoryDrawer extends StatelessWidget {
  const ChatHistoryDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final primaryColor = Theme.of(context).primaryColor;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(authProvider.currentUser?.name ?? 'Guest User'),
            accountEmail: Text(
                authProvider.currentUser?.email ?? 'Sign in for cloud sync'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: primaryColor,
              child: Text(
                authProvider.currentUser?.name[0].toUpperCase() ?? 'G',
                style: const TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.8),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chat History',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    chatProvider.createNewSession();
                    Navigator.pop(context);
                  },
                  tooltip: 'New Chat',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: chatProvider.sessions.length,
              itemBuilder: (context, index) {
                final session = chatProvider.sessions[index];
                final isSelected = session.id == chatProvider.currentSessionId;

                return ListTile(
                  leading: Icon(
                    Icons.chat_bubble_outline,
                    color: isSelected ? primaryColor : null,
                  ),
                  title: Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat('MMM d, HH:mm').format(session.lastUpdated),
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.secondary),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error),
                    onPressed: () {
                      _showDeleteSessionDialog(
                          context, chatProvider, session.id);
                    },
                  ),
                  selected: isSelected,
                  onTap: () {
                    chatProvider.switchSession(session.id);
                    Navigator.pop(context); // Close the drawer
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteSessionDialog(
      BuildContext context, ChatProvider chatProvider, String sessionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat Session'),
        content: const Text(
            'Are you sure you want to delete this chat session and all its messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              chatProvider.deleteSession(sessionId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Session deleted successfully.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ==================== CHAT SCREEN ====================

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  XFile? _selectedImage;
  // NOTE: Scaffold key is RE-INTRODUCED for the Drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

    final bool showLogout = authProvider.currentUser != null;

    return Scaffold(
      key: _scaffoldKey, // Re-added key
      drawer: const ChatHistoryDrawer(), // Re-added drawer
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildAppBar(context, showLogout, _scaffoldKey),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildChatList(chatProvider)),
            if (_selectedImage != null) _buildImagePreview(),
            _buildMessageInput(chatProvider),
          ],
        ),
      ),
    );
  }

  // NOTE: Updated _buildAppBar signature to accept the Scaffold Key
  Widget _buildAppBar(BuildContext context, bool showLogout,
      GlobalKey<ScaffoldState> scaffoldKey) {
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
          // Menu Button re-introduced
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => scaffoldKey.currentState?.openDrawer(),
            tooltip: 'Chat History',
          ),

          // Display Current Chat Name (Now displays session title)
          Expanded(
            child: Text(
              chatProvider.currentSession?.title ?? 'AI Chat Assistant',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 16),

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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.smart_toy_outlined,
                      size: 14, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    AIService.getAvailableModels()
                        .firstWhere(
                          (model) => model['id'] == chatProvider.selectedModel,
                          orElse: () => AIService.getAvailableModels().first,
                        )['name']
                        .toString()
                        .split(' ')
                        .first,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                  Icon(Icons.arrow_drop_down,
                      size: 14, color: Theme.of(context).primaryColor),
                ],
              ),
            ),
          ),

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
          // Logout Button (Hidden for Guest Users)
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
              'This is a new chat session. All history is private to the session.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Theme.of(context).colorScheme.secondary),
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
        return _buildDynamicMessageBubble(message);
      },
    );
  }

  Widget _buildDynamicMessageBubble(ChatMessage message) {
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
                if (message.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: kIsWeb
                        ? Container(
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
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  child: message.parsedContent != null
                      ? _renderStructuredContent(message.parsedContent!)
                      : MarkdownBody(
                          data: message.text,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(Theme.of(context))
                                  .copyWith(
                            p: TextStyle(
                                color: textColor, fontSize: 16, height: 1.4),
                            code: TextStyle(
                                backgroundColor: isUser
                                    ? Colors.white24
                                    : Theme.of(context)
                                        .colorScheme
                                        .secondary
                                        .withOpacity(0.2),
                                color: isUser
                                    ? Colors.yellow.shade100
                                    : Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                fontFamily: 'monospace'),
                            h1: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 20),
                            h2: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                            listBullet: TextStyle(color: textColor),
                          ),
                          onTapLink: (text, href, title) {
                            if (href != null) launchUrl(Uri.parse(href));
                          },
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

  Widget _renderStructuredContent(Map<String, dynamic> content) {
    final type = content['type'];
    final title = content['title'];

    switch (type) {
      case 'todo':
        final items = content['items'] as List<dynamic>? ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📝 $title',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white)),
            const Divider(color: Colors.white54, height: 16),
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(
                      item['done'] == true
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: item['done'] == true
                          ? Colors.lightGreenAccent
                          : Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['text'],
                        style: TextStyle(
                          color: item['done'] == true
                              ? Colors.white60
                              : Colors.white,
                          decoration: item['done'] == true
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 8),
            const Text("Tap 'Clear Chat' to remove tasks permanently.",
                style: TextStyle(fontSize: 10, color: Colors.white54)),
          ],
        );
      case 'plan':
        final steps = content['items'] as List<dynamic>? ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📅 $title',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white)),
            const Divider(color: Colors.white54, height: 16),
            ...steps.asMap().entries.map((entry) {
              int index = entry.key + 1;
              String text = entry.value['text'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: Text('$index',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(text,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14))),
                  ],
                ),
              );
            }).toList(),
          ],
        );
      default:
        return const Text(
          'Received structured data of unknown type.',
          style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
        );
    }
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
    final chatTitle = chatProvider.currentSession?.title ?? 'Untitled Chat';

    if (chatProvider.messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No messages to export in the current session'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export Chat: $chatTitle'),
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
                    chatProvider.messages, userName, chatTitle);
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
                    chatProvider.messages, userName, chatTitle);
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
                    chatProvider.messages, userName, chatTitle);
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
    final chatTitle = chatProvider.currentSession?.title ?? 'this session';

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
        content: Text(
            'Are you sure you want to clear all messages in "$chatTitle"? This action cannot be undone.'),
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
