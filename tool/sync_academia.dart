import "dart:io";

/// Copia a interface da Academia do app para o painel (usada no
/// "Visualizar como" e na previa do editor). Rode depois de mudar algo em
/// mduck_lives/lib/features/academia/{data,ui}:
///   dart run tool/sync_academia.dart
void main() {
  const from = "../mduck_lives/lib/features/academia";
  const to = "lib/features/academia/app_ui";
  for (final dir in ["data", "ui"]) {
    final src = Directory("$from/$dir");
    if (!src.existsSync()) {
      stderr.writeln("Nao achei $from/$dir");
      exit(1);
    }
    Directory("$to/$dir").createSync(recursive: true);
    for (final f in src.listSync().whereType<File>()) {
      f.copySync("$to/$dir/${f.uri.pathSegments.last}");
      stdout.writeln("ok  $dir/${f.uri.pathSegments.last}");
    }
  }
}
