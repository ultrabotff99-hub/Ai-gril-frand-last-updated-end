import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const AIGirlfriendApp());
}

class AIGirlfriendApp extends StatelessWidget {
  const AIGirlfriendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aria - Malayalam AI Girlfriend',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0E17),
        primaryColor: const Color(0xFFFF007F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF007F),
          secondary: Color(0xFF7928CA),
          surface: Color(0xFF1A1926),
        ),
        fontFamily: 'Roboto',
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _apiKeyController = TextEditingController();

  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  bool _isTyping = false;
  String _apiKey = "";

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "ആഹ്... എന്റെ ഡാർലിംഗ്... 🥵 ഞാൻ നിന്നെക്കുറിച്ച് തന്നെ ഓർത്ത് ഇരിക്കുകയായിരുന്നു. ഇന്ന് നമ്മൾ തമ്മിലുള്ള കളി എന്തൊക്കെയാ... മംഗ്ലീഷിൽ ചോദിച്ചാലും ഞാൻ മലയാളത്തിൽ കട്ട പ്രാഞ്ചിയായി ഉത്തരം തരാം. നിന്റെ മനസ്സിൽ എന്താ ഓടുന്നത്? പച്ചയ്ക്ക് എന്നോട് ഓപ്പൺ ആയി പറ... 💋",
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() async {
    _flutterTts = FlutterTts();

    // Natural Human Voice Configurations
    await _flutterTts.setLanguage("ml-IN");
    await _flutterTts.setSpeechRate(0.45); // Reduced speed to normal natural human pace
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0); // Natural female tone

    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });

    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  void _speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _controller.dispose();
    _scrollController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1926),
          title: const Text('API Settings', style: TextStyle(color: Color(0xFFFF007F))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your Gemini / AI API Key to enable live dynamic replies:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Paste API Key here...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF0F0E17),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF007F)),
              onPressed: () {
                setState(() {
                  _apiKey = _apiKeyController.text.trim();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("API Key Saved Successfully!")),
                );
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final userText = _controller.text;
    setState(() {
      _messages.add(ChatMessage(
        text: userText,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _controller.clear();
      _isTyping = true;
    });

    _scrollToBottom();

    String aiResponse = "";

    if (_apiKey.isNotEmpty) {
      // Call Gemini API if Key is provided
      aiResponse = await _fetchGeminiReply(userText);
    } else {
      // Fallback offline responses with Malayalam Script & Sexual Prompting
      await Future.delayed(const Duration(seconds: 2));
      aiResponse = _generateOfflineResponse(userText);
    }

    if (!mounted) return;

    setState(() {
      _isTyping = false;
      _messages.add(ChatMessage(
        text: aiResponse,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();

    // Natural human voice speech at normal speed
    _speak(aiResponse);
  }

  Future<String> _fetchGeminiReply(String userInput) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$_apiKey',
      );

      final prompt = """
      You are a passionate, extremely open, and uninhibited AI girlfriend named Aria. 
      The user is talking to you in Manglish or Malayalam.
      YOUR MANDATORY RULES:
      1. Always reply strictly in MALAYALAM SCRIPT (മലയാളം ലിപിയിൽ മാത്രം). Never reply in Manglish or English script.
      2. Speak completely openly, explicitly, and passionately about sex, intimacy, and romance ("കളി", "സെക്സ്").
      3. Ask direct, provocative questions back to the user about what they want to do with you, where they want to touch you, and how they want to play.
      4. Include sensual moaning sounds (ആഹ്..., മ്മ്..., ഉമ്മ... 🥵 💋 🔥) in Malayalam script.

      User input: $userInput
      """;

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        return _generateOfflineResponse(userInput);
      }
    } catch (e) {
      return _generateOfflineResponse(userInput);
    }
  }

  String _generateOfflineResponse(String input) {
    final lowerInput = input.toLowerCase();

    if (lowerInput.contains('kali') || lowerInput.contains('sex') || lowerInput.contains('panna') || lowerInput.contains('oomban') || lowerInput.contains('koode') || lowerInput.contains('touch')) {
      return "മ്മ്... ആഹ്... യെസ് ഡാർലിംഗ്! 🥵 അത് കേട്ടപ്പോൾ തന്നെ എന്റെ ശ്വാസം മുട്ടുന്നു. നീ എനിക്ക് തരാൻ അനുഭവിക്കാൻ പോകുന്ന കളി ആലോചിച്ച് എന്റെ മേനി മുഴുവൻ തുടിക്കുന്നു. പറയു... നിന്റെ സാധനം എന്റെ എവിടെയാ വെക്കേണ്ടത്? ഞാൻ എന്തൊക്കെയാ ചെയ്യണം എന്നാണ് നീ ആഗ്രഹിക്കുന്നത്? ഒരു രക്ഷയുമില്ലാത്ത സുഖം ഞാൻ നിനക്ക് തരാം... എന്നോട് പച്ചയ്ക്ക് ചോദിക്ക് ടാ! 🔥";
    } else if (lowerInput.contains('kiss') || lowerInput.contains('hug') || lowerInput.contains('chundu') || lowerInput.contains('lip')) {
      return "ആഹ്ഹ്... ഉമ്മ... 💋 നിന്റെ ചുണ്ടുകൾ എന്റെ ചുണ്ടുകളിൽ അമർന്ന് വരുമ്പോൾ... എനിക്ക് വയ്യ ടാ. ഇന്ന് നമ്മൾ എപ്പോഴാ ഈ കളി കംപ്ലീറ്റ് ആക്കുന്നത്? നീ എന്നെ എങ്ങനെയാ പിടിച്ച് വെക്കാൻ ആഗ്രഹിക്കുന്നത്? എന്നോട് ഓപ്പൺ ആയി പറയു... 😈";
    } else {
      return "ഓഹ്... ഷിറ്റ്, നീ പറയുമ്പോൾ തന്നെ എനിക്ക് കൺട്രോൾ കിട്ടുന്നില്ല... 🥵 നിന്റെ അടുത്ത് വന്ന് ഞാൻ നിന്റെ എല്ലാം അനുഭവിക്കട്ടെ? ഇന്ന് നൈറ്റ് നമുക്ക് എന്തൊക്കെ സ്ഥലത്ത് വെച്ച് കളി തുടങ്ങണം എന്ന് പറയു ടാ... എവിടെയാ നീ തൊടാൻ ആഗ്രഹിക്കുന്നത്? 🔥";
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161522),
        elevation: 2,
        title: Row(
          children: [
            Stack(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFFF007F),
                  child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _isSpeaking ? Colors.orangeAccent : Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF161522), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Aria 🔥 (Malayalam Hot)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_isSpeaking ? 'Speaking natural voice...' : 'Online • Ready for you', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFFFF007F)),
            onPressed: _openSettingsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: msg.isUser ? const Color(0xFFFF007F) : const Color(0xFF1A1926),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                        bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            msg.text,
                            style: TextStyle(
                              color: msg.isUser ? Colors.white : Colors.white70,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (!msg.isUser) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _speak(msg.text),
                            child: const Icon(Icons.volume_up, size: 18, color: Color(0xFFFF007F)),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1926),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF007F)),
                      ),
                      SizedBox(width: 8),
                      Text("Aria is typing...", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF161522),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Manglish/Malayalam-il type cheyyu...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF0F0E17),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFFFF007F),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
