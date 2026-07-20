import "package:flutter/material.dart";
import "notification_bell.dart";
import "profile_avatar_menu.dart";
import "bug_report_button.dart";

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onNotificationTap;
  const AppTopBar({super.key, this.onNotificationTap});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const BugReportButton(),
          const SizedBox(width: 4),
          NotificationBell(onNotificationTap: onNotificationTap),
          SizedBox(width: 8),
          ProfileAvatarMenu(),
        ],
      ),
    );
  }
}



