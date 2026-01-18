import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/patient_data_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Initial greeting
  List<Map<String, String>> _messages = [
    {
      'sender': 'bot',
      'text':
          'Sannu! I am Dr. Mobile Doc. I have your medical file with me. How are you feeling right now?'
    }
  ];

  bool _isLoading = false;
  bool _isListening = false; // For Mic state
  String _patientContextSummary = "Loading Patient File...";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 1. Load Context info
    String context = await PatientDataService.getContextString();
    String name = "Patient";
    if (context.contains("- Name: ")) {
      final start = context.indexOf("- Name: ") + 8;
      final end = context.indexOf("\n", start);
      if (end != -1) name = context.substring(start, end).trim();
    }

    // 2. Load History
    final history = await PatientDataService.getChatHistory();

    if (mounted) {
      setState(() {
        _patientContextSummary = "Medical File Active: $name";
        if (history.isNotEmpty) {
          _messages = history;
        }
      });
      // Scroll to bottom after loading
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
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

    // Save User Message
    await PatientDataService.saveChatMessage('user', input);

    try {
      final botResponse = await ApiService.sendToGemma(input);

      // Save Bot Message
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Placeholder for Voice Logic
  void _toggleMic() {
    setState(() {
      _isListening = !_isListening;
    });
    // In a real app, integrate 'speech_to_text' package here
    if (_isListening) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Listening... (Voice feature coming soon)")),
      );
      // Simulate listening delay then stop
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isListening = false);
      });
    }
  }

  void _speakText(String text) {
    // In a real app, integrate 'flutter_tts' package here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Reading out loud... (TTS feature coming soon)")),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textDark),
            onPressed: () {},
          ),
        ],
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

          // Quick Suggestions
          if (_messages.length <= 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _SuggestionChip("🤒 I have a fever",
                      () => _sendMessage(text: "I have a fever")),
                  _SuggestionChip("🤕 Headache",
                      () => _sendMessage(text: "I have a severe headache")),
                  _SuggestionChip("🤢 Stomach Pain",
                      () => _sendMessage(text: "My stomach hurts")),
                  _SuggestionChip("💊 Dosage Check",
                      () => _sendMessage(text: "Check my medication dosage")),
                ],
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
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: const InputDecoration(
                                hintText:
                                    'Type symptoms in English or Hausa...',
                                hintStyle:
                                    TextStyle(color: Colors.grey, fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          // Mic Button inside input
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
                  // Send Button
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
                    text,
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

          // Action buttons for Bot messages
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _speakText(text),
                    child: Row(
                      children: const [
                        Icon(Icons.volume_up_rounded,
                            size: 14, color: Colors.grey),
                        SizedBox(width: 4),
                        Text("Read Aloud",
                            style: TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.thumb_up_alt_outlined,
                      size: 14, color: Colors.grey),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
