import "package:flutter/material.dart";
import "dashboard_financeiro_page.dart";
import "entradas_saidas_page.dart";
import "colaboradores_financeiro_page.dart";
import "pagamentos_financeiro_page.dart";
import "indicacoes_page.dart";

class FinanceiroRhShell extends StatefulWidget {
  const FinanceiroRhShell({super.key});

  @override
  State<FinanceiroRhShell> createState() => _FinanceiroRhShellState();
}

class _FinanceiroRhShellState extends State<FinanceiroRhShell> {
  String _tab = "visao_geral";
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _changeMonth(int offset) {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset));
  }

  static const _monthNames = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_balance, color: Colors.amber),
            const SizedBox(width: 10),
            const Text("Centro Administrativo Financeiro", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
              child: const Text("SOMENTE DONO", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white70), onPressed: () => _changeMonth(-1)),
                Text(_monthNames[_selectedMonth.month - 1] + "/" + _selectedMonth.year.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white70), onPressed: () => _changeMonth(1)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            ("visao_geral", "Visao Geral"),
            ("entradas_saidas", "Entradas e Saidas"),
            ("pagamentos", "Pagamentos"),
            ("equipe", "Equipe"),
            ("indicacoes", "Indicacoes"),
          ].map((t) {
            final selected = _tab == t.$1;
            return ChoiceChip(
              label: Text(t.$2),
              selected: selected,
              selectedColor: Colors.amber,
              labelStyle: TextStyle(color: selected ? Colors.black : Colors.white70, fontWeight: FontWeight.bold),
              onSelected: (_) => setState(() => _tab = t.$1),
            );
          }).toList()),
          const SizedBox(height: 20),
          Expanded(
            child: _tab == "visao_geral"
                ? VisaoGeralFinanceiroPage(selectedMonth: _selectedMonth, onNavigate: (t) => setState(() => _tab = t))
                : _tab == "entradas_saidas"
                    ? EntradasSaidasPage(selectedMonth: _selectedMonth)
                    : _tab == "pagamentos"
                        ? PagamentosFinanceiroPage(selectedMonth: _selectedMonth)
                        : _tab == "equipe"
                            ? const ColaboradoresFinanceiroPage()
                            : const IndicacoesPage(),
          ),
        ],
      ),
    );
  }
}
