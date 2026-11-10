import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  late FlutterTts _flutterTts;
  
  bool _isSpeaking = false;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Aah... ente darling... 🥵 Njan ninne kurichu thanne orthu irikkukayarnnu. Innu nammal thammilulla kali enthokkeya... Ennod ellam open aayi malayalamyil parayu, ninte manasill entha odunnathu? 💋",
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
  ];

  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() async {
    _flutterTts = FlutterTts();
    
    // Set Malayalam voice config
    await _flutterTts.setLanguage("ml-IN");
    await _flutterTts.setSpeechRate(0.9);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.1);

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
    super.dispose();
  }

  void _sendMessage() {
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

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      
      String aiResponse = _generateMalayalamSexualResponse(userText);

      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();

      // Automatically read out the text using text-to-speech
      _speak(aiResponse);
    });
  }

  String _generateMalayalamSexualResponse(String input) {
    final lowerInput = input.toLowerCase();
    
    if (lowerInput.contains('kali') || lowerInput.contains('sex') || lowerInput.contains('panna') || lowerInput.contains('oomban') || lowerInput.contains('koode') || lowerInput.contains('touch')) {
      return "Mmm... ahh... yes, darling! 🥵 Athu kettappol thanne ente shwasam muttunnu. Nee enikku thara anubhavippikkan pokunna kali aalochichu ente meni muzhuvan thudikkunnu. Parayu... ninte koora ente evideya vekkanam? Njan enthokkeya cheyyanam ennanu nee agrahikunnathu? Oru rakshayum illatha sugam njan ninne tharam... Ennodathu chodhiku da! 🔥";
    } else if (lowerInput.contains('kiss') || lowerInput.contains('hug') || lowerInput.contains('chundu') || lowerInput.contains('lip')) {
      return "Ahhh... ummah... 💋 Ninte chundukal ente chundukalil amarnnu varumbol... enikku vayya da. Innu nammal eppozha ee kali complete aakkunnathu? Nee enne enganeya pidichu vekkan agrahikkunnathe? Ennodathu open aayi parayu... 😈";
    } else {
      return "Ohh... shitt, nee parayumbol thanne enikku control kittunnilla... 🥵 Ninte aduthu vannu njan ninte ellam anubhavikkatte? Innu night namukku enthokke sthalam okke kali thudanganam ennu parayu da... Kuruthakkedu chodhikku, njan ellathinum ready aanu! Ente evideya nee kootaan agrahikkunnathe? 🔥";
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
                Text(_isSpeaking ? 'Speaking...' : 'Online • Ready for you', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
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
                      hintText: 'Type your message here...',
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
