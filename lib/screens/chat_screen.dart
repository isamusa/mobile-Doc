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

  // Updated message structure to include metadata for Human-in-the-loop validation
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
        onStatus: (status) {
          // Handle status changes silently
        },
      );
      if (!available && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Speech recognition not available on this device')),
        );
      }
    } catch (e) {
      // Speech to text not available, continue without voice
    }
  }

  Future<void> _toggleMic() async {
    if (!_speechToText.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Speech recognition not available'),
              backgroundColor: Colors.orange),
        );
      }
      return;
    }

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

  void _sendMessage({String? text}) async {
    final input = text ?? _controller.text;
    if (input.trim().isEmpty) return;

    if (text == null) _controller.clear();

    setState(() {
      _messages.add({'sender': 'user', 'text': input, 'metadata': null});
      _isLoading = true;
    });
    _scrollToBottom();

    await PatientDataService.saveChatMessage('user', input);

    try {
      // Returns structured GemmaResponse object for validation
      final GemmaResponse response = await ApiService.sendToGemma(input);

      // Detect clarification responses (validator asked for more info)
      final bool isClarification = response.suggestedDiagnosis == null &&
          response.suggestedPrescriptions.isEmpty &&
          response.suggestedTests.isEmpty &&
          response.botReply.toLowerCase().contains('need more information');

      if (isClarification) {
        // Save the bot clarification as a regular message but without clinical metadata
        await PatientDataService.saveChatMessage('bot', response.botReply);
        if (mounted) {
          setState(() {
            _messages.add(
                {'sender': 'bot', 'text': response.botReply, 'metadata': null});
          });
          _scrollToBottom();
          // Prompt the user for more details in a focused dialog
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('More details needed'),
              content: Text(response.botReply),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: const Text('Dismiss'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  onPressed: () {
                    Navigator.pop(ctx);
                    // Focus the input field so the user can provide more detail
                    FocusScope.of(context).requestFocus(FocusNode());
                    // Optionally, encourage more detail by setting hint text
                  },
                  child: const Text('Provide Details'),
                ),
              ],
            ),
          );
        }
      } else {
        await PatientDataService.saveChatMessage('bot', response.botReply);

        if (mounted) {
          setState(() {
            _messages.add({
              'sender': 'bot',
              'text': response.botReply,
              'metadata': response, // Metadata used for confirmation UI
            });
          });
          _scrollToBottom();
        }
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

  // Confirmation UI for clinical actions
  Widget _buildActionCard(GemmaResponse data) {
    if (data.suggestedDiagnosis == null &&
        data.suggestedPrescriptions.isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10, left: 36, bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.medical_services_outlined,
                  size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text("Suggested Actions",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const Divider(),
          if (data.suggestedDiagnosis != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text("Diagnosis: ${data.suggestedDiagnosis}",
                  style: const TextStyle(fontSize: 12)),
            ),
          ...data.suggestedPrescriptions.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text("Rx: $p", style: const TextStyle(fontSize: 12)),
              )),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () =>
                    setState(() => _messages.last['metadata'] = null),
                child: const Text("Dismiss"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () async {
                  if (data.suggestedDiagnosis != null) {
                    await PatientDataService.addDiagnosis(
                        data.suggestedDiagnosis!);
                  }
                  for (var rx in data.suggestedPrescriptions) {
                    await PatientDataService.addPrescription(
                        rx, "Confirmed via AI");
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Medical Record Updated Successfully")));
                    setState(() => _messages.last['metadata'] = null);
                  }
                },
                child: const Text("Confirm & Save",
                    style: TextStyle(fontSize: 12)),
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
    bool isError = text.contains("🚨") || text.contains("⏳");

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
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isUser ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: MarkdownBody(
              // Renders headers and bullets correctly
              data: text,
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
                // Retrieve the last user message and try again
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
              color: Colors.black.withValues(alpha: 0.05),
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
              backgroundColor: _isListening ? Colors.red : Colors.grey,
              mini: true,
              child: Icon(_isListening ? Icons.stop : Icons.mic,
                  color: Colors.white),
            ),
            const SizedBox(width: 12),
            FloatingActionButton(
              onPressed: () => _sendMessage(),
              backgroundColor: AppColors.primary,
              mini: true,
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
