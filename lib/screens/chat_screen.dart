import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      "role": "bot",
      "text":
          "Barka da yau! I am Mobile Doc. You can speak to me in Hausa or English. How are you feeling?"
    },
  ];

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _currentLocaleId = 'ha-NG';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _controller.text = val.recognizedWords;
          }),
          localeId: _currentLocaleId,
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _sendMessage() {
    if (_controller.text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": _controller.text});
      _messages.add({"role": "bot", "text": "..."});
    });

    String userText = _controller.text;
    _controller.clear();

    // Mock Response
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _messages.removeLast();
          _messages.add({
            "role": "bot",
            "text":
                "Na ji ka (I hear you). You mentioned '$userText'. Please rest and drink water."
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Health Assistant"),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _currentLocaleId =
                    _currentLocaleId == 'en-NG' ? 'ha-NG' : 'en-NG';
              });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      "Language: ${_currentLocaleId == 'ha-NG' ? 'Hausa' : 'English'}")));
            },
            child: Text(_currentLocaleId == 'ha-NG' ? "HAUSA" : "ENGLISH",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primary)),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.userBubble : AppColors.aiBubble,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft:
                            isUser ? const Radius.circular(16) : Radius.zero,
                        bottomRight:
                            isUser ? Radius.zero : const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Text(msg['text']!,
                        style: TextStyle(
                            color: isUser ? Colors.white : AppColors.textDark)),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _listen,
                  child: CircleAvatar(
                    backgroundColor:
                        _isListening ? Colors.red : Colors.grey.shade200,
                    radius: 22,
                    child: Icon(_isListening ? Icons.mic_off : Icons.mic,
                        color: _isListening ? Colors.white : AppColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: _isListening
                                  ? "Listening..."
                                  : "Type a message...",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.send, color: AppColors.primary),
                          onPressed: _sendMessage,
                        ),
                      ],
                    ),
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
