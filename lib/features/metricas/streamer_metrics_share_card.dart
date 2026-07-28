import "package:flutter/material.dart";
import "package:flutter/services.dart";

/// Monta a mensagem pronta para o gestor mandar ao streamer. Precisa ser
/// clara por si so (o streamer nao ve o resto da tela), por isso leva nick,
/// rotulos explicitos e nao so numeros soltos.
String buildStreamerMetricsMessage({
  required String nick,
  required String categoria,
  required int diamonds,
  required int daysLive,
  required double hoursLive,
}) {
  return "Oi " +
      nick +
      "! Aqui esta o resumo do seu desempenho neste mes:\n\n"
          "Categoria: " +
      categoria +
      "\n"
          "Diamantes: " +
      diamonds.toString() +
      "\n"
          "Dias ao vivo: " +
      daysLive.toString() +
      "\n"
          "Horas ao vivo: " +
      hoursLive.toStringAsFixed(0) +
      "h";
}

/// Card clicavel que copia a mensagem de metricas do mes pronta para enviar
/// ao streamer (usado tanto em Metricas Streamers quanto no CRM).
class StreamerMetricsShareCard extends StatelessWidget {
  final String nick;
  final String categoria;
  final int diamonds;
  final int daysLive;
  final double hoursLive;

  const StreamerMetricsShareCard({
    super.key,
    required this.nick,
    required this.categoria,
    required this.diamonds,
    required this.daysLive,
    required this.hoursLive,
  });

  Future<void> _copy(BuildContext context) async {
    final text = buildStreamerMetricsMessage(
      nick: nick,
      categoria: categoria,
      diamonds: diamonds,
      daysLive: daysLive,
      hoursLive: hoursLive,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mensagem copiada. Pronta para enviar ao streamer."),
        ),
      );
    }
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Text(
            label + ": ",
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _copy(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF7A0BD4).withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF7A0BD4).withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.query_stats,
                    size: 16,
                    color: Color(0xFF7A0BD4),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      "Metricas do mes - pronto para enviar",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Icon(Icons.copy, size: 16, color: Colors.white54),
                ],
              ),
              const SizedBox(height: 8),
              _row(Icons.person, "Streamer", nick),
              _row(Icons.category, "Categoria", categoria),
              _row(Icons.diamond, "Diamantes", diamonds.toString()),
              _row(Icons.calendar_month, "Dias ao vivo", daysLive.toString()),
              _row(
                Icons.access_time,
                "Horas ao vivo",
                hoursLive.toStringAsFixed(0) + "h",
              ),
              const SizedBox(height: 6),
              const Text(
                "Toque para copiar a mensagem completa",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
