import "package:flutter/material.dart";
import "calendar_board_page.dart";

class AgendaAgenciaPage extends StatelessWidget {
  const AgendaAgenciaPage({super.key});

  @override
  Widget build(BuildContext context) => const CalendarBoardPage(mode: CalendarBoardMode.home);
}
