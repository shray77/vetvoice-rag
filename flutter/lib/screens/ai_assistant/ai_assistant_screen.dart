import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/ai_provider.dart';
import '../../models/drug_models.dart';

/// Экран AI-ассистента с RAG по ветеринарным статьям
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    context.read<AiProvider>().sendMessage(text);
    _controller.clear();

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 300), () {
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
    final provider = context.watch<AiProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.lg,
              AppSpacing.screenPadding,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI-Ассистент',
                  style: AppTypography.largeTitle.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Спрашивайте о дозировках, диагнозах, лечении',
                  style: AppTypography.subheadline.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: provider.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    itemCount: provider.messages.length + (provider.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(provider.messages[index]);
                    },
                  ),
          ),

          // Error
          if (provider.error.isNotEmpty)
            Container(
              color: AppColors.error.withAlpha(10),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      provider.error,
                      style: AppTypography.caption1.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),

          // Input bar
          _buildInputBar(provider),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Ветеринарный AI-ассистент',
              style: AppTypography.title3.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Задайте вопрос о дозировках, лечении, диагнозах или взаимодействиях препаратов',
              style: AppTypography.subheadline.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            // Quick prompts
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _quickChip('Дозировка энрофлоксацина для собак'),
                _quickChip('Взаимодействие фторхинолонов'),
                _quickChip('Лечение лептоспироза у КРС'),
                _quickChip('Противопоказания при беременности'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickChip(String text) {
    return ActionChip(
      label: Text(
        text,
        style: AppTypography.caption1.copyWith(color: AppColors.primary),
      ),
      backgroundColor: AppColors.primary.withAlpha(10),
      side: const BorderSide(color: AppColors.primary, width: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
      onPressed: () {
        _controller.text = text;
        _sendMessage();
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: message.isUser
                ? AppColors.primary
                : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.large),
              topRight: const Radius.circular(AppRadius.large),
              bottomLeft: message.isUser
                  ? const Radius.circular(AppRadius.large)
                  : const Radius.circular(4),
              bottomRight: message.isUser
                  ? const Radius.circular(4)
                  : const Radius.circular(AppRadius.large),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            message.content,
            style: AppTypography.subheadline.copyWith(
              color: message.isUser ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withAlpha(100),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Думаю...',
                style: AppTypography.caption1.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(AiProvider provider) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Спросите о ветеринарии...',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                enabled: !provider.isLoading,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: provider.isLoading
                  ? AppColors.textTertiary
                  : AppColors.primary,
              child: IconButton(
                icon: Icon(
                  provider.isLoading ? Icons.hourglass_empty : Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: provider.isLoading ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
