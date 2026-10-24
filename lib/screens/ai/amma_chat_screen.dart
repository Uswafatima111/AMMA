import 'package:flutter/material.dart';

import '../../ai/amma_ai_service.dart';

class AmmaChatScreen extends StatefulWidget {
  const AmmaChatScreen({super.key});

  @override
  State<AmmaChatScreen> createState() => _AmmaChatScreenState();
}

class _AmmaChatScreenState extends State<AmmaChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AmmaAiService _aiService = AmmaAiService();

  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          'Assalamu alaikum! I am AMMA, your maternal-health '
          'information assistant. You can ask me questions about '
          'pregnancy health. I do not replace a healthcare professional.',
      isUser: false,
    ),
  ];

  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final question = _messageController.text.trim();

    if (question.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _messageController.clear();
      _isSending = true;
    });

    // Allow the user's message to render before processing.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final response = _aiService.ask(question);

    if (!mounted) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          text: response.answer,
          isUser: false,
          requiresUrgentCare: response.requiresUrgentCare,
          sources: response.sources,
        ),
      );
      _isSending = false;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AMMA Assistant'),
            Text('Maternal-health information', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Text(
              'For emergencies, seek urgent professional '
              'medical help. Do not wait for a chat response.',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Ask a pregnancy health question...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: const Icon(Icons.send),
                    tooltip: 'Send message',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatMessage message) {
    final colors = Theme.of(context).colorScheme;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: message.requiresUrgentCare
              ? colors.errorContainer
              : message.isUser
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: message.requiresUrgentCare
              ? Border.all(color: colors.error)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.requiresUrgentCare) ...[
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: colors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'URGENT SAFETY MESSAGE',
                      style: TextStyle(
                        color: colors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SelectableText(message.text),
            if (message.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const Text(
                'Retrieved knowledge entries',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...message.sources.map(
                (source) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $source',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool requiresUrgentCare;
  final List<String> sources;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.requiresUrgentCare = false,
    this.sources = const [],
  });
}
