import 'package:flutter/material.dart';

void main() {
  runApp(const AIGirlfriendApp());
}

class AIGirlfriendApp extends StatelessWidget {
  const AIGirlfriendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aria - AI Companion',
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
  
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Hey... I was just thinking about you. How was your day? Tell me everything...",
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
  ];

  bool _isTyping = false;

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
      
      String aiResponse = _generateResponse(userText);

      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
  }

  String _generateResponse(String input) {
    return "I'm right here with you. What else is on your mind? Tell me more...";
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
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF161522), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aria', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Online • Always here for you', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                final message = _messages[index];
                return Align(
                  alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: message.isUser 
                          ? const Color(0xFFFF007F) 
                          : const Color(0xFF1A1926),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                        bottomRight: Radius.circular(message.isUser ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : Colors.white70,
                        fontSize: 15,
                        height: 1.3,
                      ),
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
                      hintText: 'Type your message...',
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
