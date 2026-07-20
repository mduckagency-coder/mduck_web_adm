import "dart:html" as html;
import "package:excel/excel.dart";

const _typeLabelsExport = {
  "despesa": "Despesa",
  "receita": "Receita",
  "salario": "Salario",
  "comissao": "Comissao",
  "ajuda_custo": "Ajuda de Custo",
  "bonificacao": "Bonificacao",
  "premiacao": "Premiacao",
  "indicacao": "Indicacao",
};

void exportFinancialEntriesReport(List<Map<String, dynamic>> entries, DateTime month) {
  final workbook = Excel.createExcel();
  final sheet = workbook["Relatorio"];
  workbook.delete("Sheet1");

  sheet.appendRow([
    TextCellValue("Tipo"),
    TextCellValue("Categoria"),
    TextCellValue("Descricao"),
    TextCellValue("Fornecedor"),
    TextCellValue("Valor"),
    TextCellValue("Vencimento"),
    TextCellValue("Status"),
    TextCellValue("Data Pagamento"),
  ]);

  for (final e in entries) {
    sheet.appendRow([
      TextCellValue(_typeLabelsExport[e["entry_type"]] ?? (e["entry_type"] as String? ?? "-")),
      TextCellValue((e["category"] as String?) ?? "-"),
      TextCellValue((e["description"] as String?) ?? "-"),
      TextCellValue((e["supplier"] as String?) ?? "-"),
      DoubleCellValue((e["amount"] as num).toDouble()),
      TextCellValue((e["due_date"] as String?) ?? "-"),
      TextCellValue((e["status"] as String?) ?? "-"),
      TextCellValue((e["payment_date"] as String?) ?? "-"),
    ]);
  }

  final bytes = workbook.encode();
  if (bytes == null) return;

  final fileName = "relatorio_financeiro_" + month.year.toString() + "-" + month.month.toString().padLeft(2, "0") + ".xlsx";
  final blob = html.Blob([bytes], "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
