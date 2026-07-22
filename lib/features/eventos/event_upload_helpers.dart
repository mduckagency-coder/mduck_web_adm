import "package:file_picker/file_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";

String _sanitizedExtension(String fileName) {
  final dotIndex = fileName.lastIndexOf(".");
  final rawExt = dotIndex != -1 ? fileName.substring(dotIndex + 1) : "";
  return RegExp(r"^[a-zA-Z0-9]{1,6}$").hasMatch(rawExt) ? rawExt.toLowerCase() : "bin";
}

/// Sobe um arquivo pra um bucket com uma chave sanitizada
/// (`prefixo_timestamp.ext`), nunca o nome cru do arquivo (evita erro 400
/// InvalidKey quando o nome tem espaco/acento/caractere especial).
Future<String> uploadEventFile({
  required String bucket,
  required String prefix,
  required PlatformFile file,
}) async {
  final client = Supabase.instance.client;
  final ext = _sanitizedExtension(file.name);
  final path = prefix + "_" + DateTime.now().millisecondsSinceEpoch.toString() + "." + ext;
  await client.storage.from(bucket).uploadBinary(path, file.bytes!);
  return client.storage.from(bucket).getPublicUrl(path);
}
