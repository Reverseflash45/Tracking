import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hero_header.dart';
import '../data/assistant_repository.dart';
import '../domain/data_context.dart';

const _color = AppColors.dashboard;

/// Pertanyaan contoh. Bukan sekadar hiasan: tanpa ini user menebak-nebak apa
/// yang bisa ditanyakan, lalu bertanya hal di luar jangkauan datanya dan
/// menyimpulkan fiturnya rusak.
const _contohPertanyaan = [
  'Bulan ini aku lari berapa km?',
  'Tugas apa yang paling mendesak?',
  'Pengeluaran terbesarku ke mana?',
  'Latihan apa yang paling sering aku lakukan?',
  'Rata-rata kalori harianku berapa?',
];

class _Turn {
  const _Turn({required this.question, this.answer, this.error});

  final String question;
  final String? answer;
  final String? error;

  bool get pending => answer == null && error == null;
}

class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Turn> _turns = [];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ask(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || _sending) return;

    final context = ref.read(dataContextProvider);
    if (context == null) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Datamu masih dimuat, tunggu sebentar')),
      );
      return;
    }

    setState(() {
      _turns.add(_Turn(question: trimmed));
      _sending = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final answer = await ref
          .read(assistantRepositoryProvider)
          .tanya(question: trimmed, context: context);
      if (!mounted) return;
      setState(() {
        _turns[_turns.length - 1] = _Turn(question: trimmed, answer: answer);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _turns[_turns.length - 1] = _Turn(question: trimmed, error: '$e');
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final siap = ref.watch(dataContextProvider) != null;

    return Scaffold(
      body: Column(
        children: [
          HeroHeader.sub(
            title: 'Tanya Data',
            subtitle: 'Tanya apa saja tentang catatanmu sendiri',
            color: _color,
            leading: HeroIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: () => context.pop(),
            ),
          ),
          Expanded(
            child: _turns.isEmpty
                ? _Pembuka(onPick: _ask, siap: siap)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _turns.length,
                    itemBuilder: (context, index) => _TurnView(turn: _turns[index]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _ask,
                      enabled: siap && !_sending,
                      decoration: InputDecoration(
                        hintText: siap ? 'Tanya sesuatu...' : 'Memuat datamu...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    onPressed: siap && !_sending ? () => _ask(_controller.text) : null,
                    style: IconButton.styleFrom(
                      backgroundColor: _color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: _sending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              'Jawaban hanya dari data $kContextDays hari terakhir di app ini. '
              'Kalau angkanya terasa aneh, percaya catatanmu — bukan jawabannya.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.35,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pembuka extends StatelessWidget {
  const _Pembuka({required this.onPick, required this.siap});

  final void Function(String) onPick;
  final bool siap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_outlined, size: 30, color: _color),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Tanya apa pun tentang datamu',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Coba salah satu ini:',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final contoh in _contohPertanyaan)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                dense: true,
                enabled: siap,
                onTap: () => onPick(contoh),
                title: Text(contoh, style: const TextStyle(fontSize: 13)),
                trailing: const Icon(Icons.north_east, size: 16),
              ),
            ),
          ),
      ],
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({required this.turn});

  final _Turn turn;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              turn.question,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
            ),
          ),
        ),
        if (turn.pending)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg, left: 4),
            child: Row(
              children: [
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _color),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Membaca datamu...',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          )
        else if (turn.error != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: colorScheme.onErrorContainer),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    turn.error!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg, left: 4, right: 24),
            child: Text(
              turn.answer!,
              style: const TextStyle(fontSize: 13.5, height: 1.5),
            ),
          ),
      ],
    );
  }
}
