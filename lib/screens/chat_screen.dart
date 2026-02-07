import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/patient_data_service.dart';

class ChatScreen extends StatefulWidget {
  final String? initialQuery; // 👈 Receives the scan result
  const ChatScreen({super.key, this.initialQuery});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Unified Message Structure: List of Maps
  List<Map<String, String>> _messages = [
    {
      'sender': 'bot',
      'text':
          'Sannu! I am Dr. Mobile Doc. I have your medical file. How are you feeling right now?'
    }
  ];

  bool _isLoading = false;
  bool _isListening = false;
  String _patientContextSummary = "Loading Patient File...";

  @override
  void initState() {
    super.initState();
    _loadData();

    // 🚀 Handle the Scan Result immediately on load
    if (widget.initialQuery != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleInitialMessage(widget.initialQuery!);
      });
    }
  }

  // 🚀 Logic to handle the "Consult Doctor" message automatically
  void _handleInitialMessage(String msg) async {
    setState(() {
      _messages.add({'sender': 'user', 'text': msg});
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await ApiService.sendToGemma(msg);

      if (mounted) {
        setState(() {
          _messages.add({'sender': 'bot', 'text': response});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    String context = await PatientDataService.getContextString();
    String name = "Patient";
    if (context.contains("- Name: ")) {
      final start = context.indexOf("- Name: ") + 8;
      final end = context.indexOf("\n", start);
      if (end != -1) name = context.substring(start, end).trim();
    }

    final history = await PatientDataService.getChatHistory();

    if (mounted) {
      setState(() {
        _patientContextSummary = "Medical File Active: $name";
        if (history.isNotEmpty && widget.initialQuery == null) {
          _messages = history;
        }
      });
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

  void _sendMessage({String? text}) async {
    final input = text ?? _controller.text;
    if (input.trim().isEmpty) return;

    if (text == null) _controller.clear();

    setState(() {
      _messages.add({'sender': 'user', 'text': input});
      _isLoading = true;
    });
    _scrollToBottom();

    await PatientDataService.saveChatMessage('user', input);

    try {
      final botResponse = await ApiService.sendToGemma(input);
      await PatientDataService.saveChatMessage('bot', botResponse);

      if (mounted) {
        setState(() {
          _messages.add({'sender': 'bot', 'text': botResponse});
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
              {'sender': 'bot', 'text': 'Network error. Please try again.'});
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleMic() {
    setState(() => _isListening = !_isListening);
    if (_isListening) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Listening... (Voice feature coming soon)")),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isListening = false);
      });
    }
  }

  void _speakText(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Reading out loud... (TTS feature coming soon)")),
    );
  }

  // 🧹 Helper to Clean AI Markdown
  String _cleanResponse(String text) {
    return text
        .replaceAll('**', '') // Remove bold markers
        .replaceAll('##', '') // Remove header markers
        .replaceAll(RegExp(r'^\* ', multiLine: true),
            '• ') // Replace list asterisk with bullet
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.secondary,
                  child: Icon(Icons.smart_toy, color: AppColors.primary),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Dr. Mobile Doc',
                    style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text('AI Consultant • Online',
                    style: TextStyle(color: Colors.green, fontSize: 12)),
              ],
            )
          ],
        ),
      ),
      body: Column(
        children: [
          // Context Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(bottom: BorderSide(color: Colors.blue.shade100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  _patientContextSummary,
                  style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return _buildMessageBubble(msg['text']!, isUser);
              },
            ),
          ),

          // Typing Indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text("Dr. Mobile Doc is typing...",
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10)
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        // 🎨 INPUT BACKGROUND: Light Gray for visibility
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              // 🎨 TEXT COLOR: Black for contrast
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.black87),
                              decoration: const InputDecoration(
                                hintText: 'Type symptoms here...',
                                hintStyle:
                                    TextStyle(color: Colors.grey, fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          GestureDetector(
                            onTap: _toggleMic,
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isListening
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: _isListening
                                    ? Colors.red
                                    : Colors.grey.shade600,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _sendMessage(),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    // Apply formatting only to bot messages
    final String displayText = isUser ? text : _cleanResponse(text);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.secondary,
                  child:
                      Icon(Icons.smart_toy, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isUser
                          ? const Radius.circular(20)
                          : const Radius.circular(4),
                      bottomRight: isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(20),
                    ),
                    boxShadow: [
                      if (!isUser)
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2))
                    ],
                    border: !isUser
                        ? Border.all(color: Colors.grey.shade100)
                        : null,
                  ),
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF2D3748),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
