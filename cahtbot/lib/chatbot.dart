import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();


  final String apiKey =
      "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"; // provided by user

  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _bgAnim;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _bgAnim = AnimationController(vsync: this, duration: const Duration(seconds: 18))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _bgAnim.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('chat_messages');
    if (saved != null) {
      setState(() {
        final list = jsonDecode(saved) as List;
        _messages.clear();
        _messages.addAll(list.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)));
      });
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_messages', jsonEncode(_messages));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || _sending) return;

    final userText = _controller.text.trim();
    _controller.clear();

    setState(() {
      _sending = true;
      _messages.add({"text": userText, "isUser": true});
      _messages.add({"text": "Bot is typing...", "isUser": false, "isTyping": true});
    });
    _saveMessages();
    _scrollToBottom();

    String responseText;

    try {
      final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": "gpt-4o-mini",
          "messages": [
            {"role": "user", "content": userText}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        responseText = data['choices'][0]['message']['content'] ?? 'No response';
      } else {
        responseText = "Error: ${response.statusCode}";
      }
    } catch (e) {
      responseText = "Error: $e";
    }

    setState(() {
      _messages.removeWhere((m) => m['isTyping'] == true);
      _messages.add({"text": responseText, "isUser": false});
      _sending = false;
    });
    _saveMessages();
    _scrollToBottom();
  }

  Future<void> _clearChat() async {
    setState(() => _messages.clear());
    await _saveMessages();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          _AnimatedGradientBackground(controller: _bgAnim),
          SafeArea(
            child: Column(
              children: [
                // Top App Bar (custom, with subtle entrance animation)
                _GlassAppBar(
                  onClear: _messages.isNotEmpty ? _clearChat : null,
                ),
                // Messages list
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 8, top: 6),
                    child: _MessagesList(
                      messages: _messages,
                      controller: _scrollController,
                    ),
                  ),
                ),
                // Input bar
                Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: max(MediaQuery.of(context).viewInsets.bottom, 12),
                  ),
                  child: _InputBar(
                    controller: _controller,
                    onSend: _sendMessage,
                    enabled: !_sending,
                    cs: cs,
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

class _GlassAppBar extends StatelessWidget {
  final VoidCallback? onClear;
  const _GlassAppBar({this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          const _WavyBotAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Aurora AI',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                _OnlinePill(),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear chat',
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _OnlinePill extends StatelessWidget {
  const _OnlinePill();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _PulseDot(),
          SizedBox(width: 6),
          Text('Online • ready to help', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final v = Curves.easeInOut.transform((_c.value * 2) % 1);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 8 + v * 6,
                height: 8 + v * 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.15 + 0.15 * (1 - v)),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              )
            ],
          );
        },
      ),
    );
  }
}

class _WavyBotAvatar extends StatefulWidget {
  const _WavyBotAvatar();
  @override
  State<_WavyBotAvatar> createState() => _WavyBotAvatarState();
}

class _WavyBotAvatarState extends State<_WavyBotAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              startAngle: 0,
              endAngle: pi * 2,
              colors: [
                const Color(0xFF8EC5FC),
                const Color(0xFFE0C3FC),
                const Color(0xFF8EC5FC),
              ],
              stops: [t, (t + 0.4) % 1, (t + 1) % 1],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: const Icon(Icons.smart_toy_outlined, color: Colors.white),
        );
      },
    );
  }
}

class _MessagesList extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final ScrollController controller;
  const _MessagesList({required this.messages, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 6),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final m = messages[index];
        return _AnimatedMessageBubble(message: m, index: index);
      },
    );
  }
}

class _AnimatedMessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final int index;
  const _AnimatedMessageBubble({required this.message, required this.index});

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween(begin: 12.0, end: 0.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    // Stagger by index for a cascading effect
    Future.delayed(Duration(milliseconds: 40 * (widget.index % 8)), () => _c.forward());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message['isUser'] == true;
    final isTyping = widget.message['isTyping'] == true;

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(isUser ? _slide.value : -_slide.value, 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF1B3B6F) : Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: isUser
                          ? null
                          : Border.all(color: Colors.black.withOpacity(0.05)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: isTyping
                          ? const _TypingIndicator()
                          : Text(
                        widget.message['text'] ?? '',
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                          fontSize: 16,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = ((_c.value + i / 3) % 1.0);
            final s = 0.6 + 0.4 * sin(t * pi * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: s,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35 + 0.35 * s),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final ColorScheme cs;
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.enabled,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                maxLines: 5,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Type a message…',
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(onTap: enabled ? onSend : null),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  final VoidCallback? onTap;
  const _SendButton({this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return GestureDetector(
      onTapDown: enabled
          ? (_) {
        _c.forward(from: 0);
      }
          : null,
      onTapUp: enabled
          ? (_) {
        widget.onTap?.call();
      }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
            colors: [Color(0xFF1B3B6F), Color(0xFF6D83F2)],
          )
              : LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade300]),
          shape: BoxShape.circle,
          boxShadow: [
            if (enabled)
              BoxShadow(
                color: const Color(0xFF1B3B6F).withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: ScaleTransition(
          scale: Tween(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.elasticOut)),
          child: const Icon(Icons.send_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _AnimatedGradientBackground extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedGradientBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(controller.value);
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFFe0f2ff), const Color(0xFFf3e8ff), t)!,
                Color.lerp(const Color(0xFFdbeafe), const Color(0xFFede9fe), 1 - t)!,
              ],
            ),
          ),
        );
      },
    );
  }
}
