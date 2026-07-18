import "package:flutter/material.dart";
import "notification_bell.dart";
import "profile_avatar_menu.dart";

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          NotificationBell(),
          SizedBox(width: 8),
          ProfileAvatarMenu(),
        ],
      ),
    );
  }
}
