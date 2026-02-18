import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/patient_data_service.dart';

class ChatScreen extends StatefulWidget {
  final String? initialQuery;
  const ChatScreen({super.key, this.initialQuery});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late stt.SpeechToText _speechToText;
  bool _isListening = false;

  List<Map<String, dynamic>> _messages = [
    {
      'sender': 'bot',
      'text':
          'Sannu! I am Dr. Mobile Doc. I have your medical file. How are you feeling right now?',
      'metadata': null
    }
  ];

  bool _isLoading = false;
  String _patientContextSummary = "Loading Patient File...";

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _initializeSpeechToText();
    _loadData();

    if (widget.initialQuery != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(text: widget.initialQuery);
      });
    }
  }

  Future<void> _initializeSpeechToText() async {
    try {
      bool available = await _speechToText.initialize(
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Speech error: ${error.errorMsg}')),
            );
          }
        },
      );
      if (!available && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
    } catch (e) {
      // Continue without voice
    }
  }

  Future<void> _toggleMic() async {
    if (!_speechToText.isAvailable) return;

    if (!_isListening) {
      try {
        bool available = await _speechToText.initialize();
        if (available) {
          setState(() => _isListening = true);
          _speechToText.listen(
            onResult: (result) {
              setState(() {
                _controller.text = result.recognizedWords;
              });
            },
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 3),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error starting speech: $e')),
          );
        }
      }
    } else {
      _speechToText.stop();
      setState(() => _isListening = false);
    }
  }

  @override
  void dispose() {
    _speechToText.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
          _messages = history.map((m) => {...m, 'metadata': null}).toList();
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

  // 🧠 MEMORY HELPER: Get last few messages to send to AI
  String _getRecentHistory() {
    if (_messages.isEmpty) return "";
    int start = _messages.length > 6 ? _messages.length - 6 : 0;
    var recent = _messages.sublist(start);
    return recent.map((m) {
      String role = m['sender'] == 'user' ? 'PATIENT' : 'DOCTOR';
      return "$role: ${m['text']}";
    }).join("\n");
  }

  void _sendMessage({String? text}) async {
    final input = text ?? _controller.text;
    if (input.trim().isEmpty) return;

    if (text == null) _controller.clear();

    // 1. Gather history before adding new message
    String historyText = _getRecentHistory();

    setState(() {
      _messages.add({'sender': 'user', 'text': input, 'metadata': null});
      _isLoading = true;
    });
    _scrollToBottom();

    await PatientDataService.saveChatMessage('user', input);

    // 2. Build Enriched Prompt
    String enrichedInput = historyText.isNotEmpty
        ? "[RECENT CHAT HISTORY]:\n$historyText\n\n[CURRENT MESSAGE]: $input"
        : input;

    try {
      // 3. Send to AI
      final dynamic response = await ApiService.sendToGemma(enrichedInput);

      await PatientDataService.saveChatMessage('bot', response.botReply);

      // 4. Update UI - ALWAYS show the text message, NO blocking modals
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text': response.botReply,
            'metadata': response, // Pass metadata to trigger the Action Card
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({
            'sender': 'bot',
            'text': 'Network error. Please try again.',
            'metadata': null
          });
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🩺 INLINE ACTION CARD (Replaces the annoying Modal)
  Widget _buildActionCard(dynamic data) {
    // Only show if there is actually a diagnosis or test suggested
    bool hasDiagnosis = data.suggestedDiagnosis != null &&
        data.suggestedDiagnosis.toString().trim().isNotEmpty;
    bool hasPrescriptions = data.suggestedPrescriptions != null &&
        data.suggestedPrescriptions.isNotEmpty;
    bool hasTests =
        data.suggestedTests != null && data.suggestedTests.isNotEmpty;

    if (!hasDiagnosis && !hasPrescriptions && !hasTests) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, left: 40, bottom: 16, right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_hospital,
                  size: 18, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Text(
                "Tell Your Physical Doctor:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Please visit a clinic and show the doctor this summary:",
            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
          ),
          const Divider(),
          if (hasDiagnosis)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                "• Suspected: ${data.suggestedDiagnosis}",
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          if (hasTests)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                "• Request Tests: ${data.suggestedTests.join(', ')}",
                style: const TextStyle(fontSize: 13),
              ),
            ),
          if (hasPrescriptions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                "• Discuss Meds: ${data.suggestedPrescriptions.join(', ')}",
                style: const TextStyle(fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() => _messages.last['metadata'] = null);
                },
                child: Text("Dismiss",
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (hasDiagnosis) {
                    await PatientDataService.addDiagnosis(
                        "[AI Suspected] ${data.suggestedDiagnosis}");
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Saved to your Medical Records")),
                    );
                    setState(() => _messages.last['metadata'] = null);
                  }
                },
                child: const Text("Save to Records"),
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('Dr. Mobile Doc',
            style: TextStyle(
                color: AppColors.textDark, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          _buildContextBanner(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMessageBubble(msg['text']!, isUser),
                    if (msg['metadata'] != null)
                      _buildActionCard(msg['metadata']),
                  ],
                );
              },
            ),
          ),
          if (_isLoading) _buildLoadingIndicator(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    bool isError = text.contains("Network error");

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 8),
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
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
              ],
            ),
            child: MarkdownBody(
              data: text.replaceAll('**', ''), // Clean up excessive bolding
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                    color: isUser ? Colors.white : AppColors.textDark,
                    fontSize: 15,
                    height: 1.5),
                listBullet:
                    TextStyle(color: isUser ? Colors.white : AppColors.primary),
              ),
            ),
          ),
        ),
        if (!isUser && isError)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 12),
            child: TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text("Retry Connection",
                  style: TextStyle(fontSize: 12)),
              onPressed: () {
                final lastUserMsg = _messages.reversed
                    .firstWhere((m) => m['sender'] == 'user')['text'];
                _sendMessage(text: lastUserMsg);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildContextBanner() {
    return Container(
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
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
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
    );
  }

  Widget _buildInputArea() {
    return Container(
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
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  decoration: const InputDecoration(
                    hintText: 'Describe your symptoms...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FloatingActionButton(
              onPressed: _toggleMic,
              backgroundColor: _isListening ? Colors.red : Colors.grey.shade300,
              elevation: 0,
              mini: true,
              child: Icon(_isListening ? Icons.stop : Icons.mic,
                  color: _isListening ? Colors.white : Colors.black54),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              onPressed: () => _sendMessage(),
              backgroundColor: AppColors.primary,
              elevation: 0,
              mini: true,
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
