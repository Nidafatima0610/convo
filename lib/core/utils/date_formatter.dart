class DateFormatter {
  DateFormatter._();

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _fullMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Format time as "10:30 AM" or "4:05 PM"
  static String formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$formattedHour:$minute $period';
  }

  /// Format conversation list timestamp:
  /// - Today: "10:30 AM"
  /// - Yesterday: "Yesterday"
  /// - Within 7 days: "Wed"
  /// - Older: "Oct 12"
  /// - Different year: "10/12/25"
  static String formatConversationTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final local = dateTime.toLocal();

    final isSameDay =
        now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;
    if (isSameDay) {
      return formatTime(local);
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        yesterday.year == local.year &&
        yesterday.month == local.month &&
        yesterday.day == local.day;
    if (isYesterday) {
      return 'Yesterday';
    }

    final difference = now.difference(local);
    if (difference.inDays < 7 && now.weekday != local.weekday) {
      return _weekdays[local.weekday - 1];
    }

    if (now.year == local.year) {
      return '${_months[local.month - 1]} ${local.day}';
    }

    return '${local.month}/${local.day}/${local.year.toString().substring(2)}';
  }

  /// Format date divider in chat messages:
  /// - "Today"
  /// - "Yesterday"
  /// - "Monday, October 12"
  static String formatChatDateDivider(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();

    final isSameDay =
        now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;
    if (isSameDay) {
      return 'Today';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        yesterday.year == local.year &&
        yesterday.month == local.month &&
        yesterday.day == local.day;
    if (isYesterday) {
      return 'Yesterday';
    }

    final weekdayName = _weekdays[local.weekday - 1];
    final monthName = _fullMonths[local.month - 1];
    return '$weekdayName, $monthName ${local.day}${now.year != local.year ? ', ${local.year}' : ''}';
  }

  /// Format relative timestamp for last seen:
  /// - "just now"
  /// - "5m ago"
  /// - "2h ago"
  /// - "yesterday at 10:30 AM"
  /// - "3d ago"
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime.toLocal());

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'yesterday at ${formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return formatConversationTime(dateTime);
    }
  }
}
