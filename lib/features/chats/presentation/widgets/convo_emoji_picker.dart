import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/extensions.dart';

class ConvoEmojiPicker extends StatefulWidget {
  const ConvoEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onBackspace,
  });

  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onBackspace;

  @override
  State<ConvoEmojiPicker> createState() => _ConvoEmojiPickerState();
}

class _ConvoEmojiPickerState extends State<ConvoEmojiPicker> {
  int _selectedCategoryIndex = 0;

  static const List<({String title, IconData icon, List<String> emojis})>
  _categories = [
    (
      title: 'Smileys',
      icon: Icons.sentiment_satisfied_alt_rounded,
      emojis: [
        '😀',
        '😃',
        '😄',
        '😁',
        '😆',
        '😅',
        '😂',
        '🤣',
        '😊',
        '😇',
        '🙂',
        '🙃',
        '😉',
        '😌',
        '😍',
        '🥰',
        '😘',
        '😗',
        '😙',
        '😚',
        '😋',
        '😛',
        '😝',
        '😜',
        '🤪',
        '🤨',
        '🧐',
        '🤓',
        '😎',
        '🤩',
        '🥳',
        '😏',
        '😒',
        '😞',
        '😔',
        '😟',
        '😕',
        '🙁',
        '😣',
        '😖',
        '😫',
        '😩',
        '🥺',
        '😢',
        '😭',
        '😤',
        '😠',
        '😡',
        '🤬',
        '🤯',
        '😳',
        '🥵',
        '🥶',
        '😱',
        '😨',
        '😰',
        '😥',
        '😓',
        '🤗',
        '🤔',
        '🤭',
        '🤫',
        '🤥',
        '😶',
        '😐',
        '😑',
        '😬',
        '🙄',
        '😯',
        '😦',
        '😮',
        '😲',
        '🥱',
        '😴',
        '🤤',
        '😪',
        '😵',
        '🤐',
        '🥴',
        '🤢',
      ],
    ),
    (
      title: 'Gestures',
      icon: Icons.thumb_up_alt_rounded,
      emojis: [
        '👋',
        '🤚',
        '🖐',
        '✋',
        '🖖',
        '👌',
        '🤌',
        '🤏',
        '✌',
        '🤞',
        '🤟',
        '🤘',
        '🤙',
        '👈',
        '👉',
        '👆',
        '🖕',
        '👇',
        '☝',
        '👍',
        '👎',
        '✊',
        '👊',
        '🤛',
        '🤜',
        '👏',
        '🙌',
        '👐',
        '🤲',
        '🤝',
        '🙏',
        '✍',
        '💅',
        '🤳',
        '💪',
        '🦾',
        '🦿',
        '🦵',
        '🦶',
        '👂',
      ],
    ),
    (
      title: 'Hearts',
      icon: Icons.favorite_rounded,
      emojis: [
        '❤️',
        '🧡',
        '💛',
        '💚',
        '💙',
        '💜',
        '🖤',
        '🤍',
        '🤎',
        '💔',
        '❣️',
        '💕',
        '💞',
        '💓',
        '💗',
        '💖',
        '💘',
        '💝',
        '💟',
        '💌',
        '💋',
        '💯',
        '💢',
        '💥',
        '💫',
        '💬',
        '👁‍🗨',
        '🗨',
        '🗯',
        '💭',
      ],
    ),
    (
      title: 'Objects',
      icon: Icons.celebration_rounded,
      emojis: [
        '✨',
        '🎉',
        '🎊',
        '🎈',
        '🎁',
        '🏆',
        '🥇',
        '🥈',
        '🥉',
        '⚽',
        '🏀',
        '🏈',
        '⚾',
        '🎾',
        '🏐',
        '🏉',
        '🎱',
        '🏓',
        '🏸',
        '🥊',
        '🎮',
        '🎲',
        '🧩',
        '🎯',
        '🎳',
        '🔥',
        '⭐',
        '🌟',
        '⚡',
        '🌙',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentCategory = _categories[_selectedCategoryIndex];

    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: context.convoColors.cardBackground,
        border: Border(
          top: BorderSide(color: context.convoColors.cardBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Category Selector
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.convoColors.surfaceSubtle,
              border: Border(
                bottom: BorderSide(
                  color: context.convoColors.cardBorder,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == _selectedCategoryIndex;
                      final cat = _categories[index];

                      return IconButton(
                        tooltip: cat.title,
                        icon: Icon(
                          cat.icon,
                          size: 20,
                          color: isSelected
                              ? context.colorScheme.primary
                              : context.convoColors.textTertiary,
                        ),
                        onPressed: () {
                          setState(() => _selectedCategoryIndex = index);
                        },
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.backspace_outlined,
                    size: 20,
                    color: context.convoColors.textSecondary,
                  ),
                  tooltip: 'Backspace',
                  onPressed: widget.onBackspace,
                ),
              ],
            ),
          ),

          // Emoji Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.sm),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: currentCategory.emojis.length,
              itemBuilder: (context, index) {
                final emoji = currentCategory.emojis[index];
                return InkWell(
                  onTap: () => widget.onEmojiSelected(emoji),
                  borderRadius: AppRadius.borderSm,
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
