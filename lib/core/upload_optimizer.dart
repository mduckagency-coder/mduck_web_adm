import "dart:typed_data";

import "package:image/image.dart" as img;

/// Limite de video/audio que vai para o APP (cada streamer baixa o arquivo;
/// arquivo grande = muito trafego no Supabase).
const appVideoMaxMb = 20;

/// Maior lado das imagens enviadas (celular nao precisa de mais que isso).
const _maxImageSide = 1600;

class UploadTooLarge implements Exception {
  final String message;
  UploadTooLarge(this.message);
  @override
  String toString() => message;
}

/// Prepara um arquivo antes de subir para o Storage:
///   * imagens (jpg/png/webp) grandes sao redimensionadas para no maximo
///     1600px e comprimidas (PNG com transparencia continua PNG);
///   * videos/audios para o app acima de [appVideoMaxMb] sao recusados com
///     uma mensagem explicando como reduzir.
/// Devolve os bytes (talvez menores) e a extensao final.
({Uint8List bytes, String ext}) optimizeUpload(Uint8List bytes, String ext, {bool forApp = true}) {
  final e = ext.toLowerCase();
  final mb = bytes.length / (1024 * 1024);
  if (forApp && const {"mp4", "mov", "webm", "m4v", "mp3", "m4a", "aac", "wav", "ogg"}.contains(e) && mb > appVideoMaxMb) {
    throw UploadTooLarge(
      "Arquivo com ${mb.toStringAsFixed(1)} MB. Para o app, use até $appVideoMaxMb MB: "
      "exporte em 720p (ou menor), com duração curta e compressão (ex.: HandBrake, CapCut ou um compressor online). "
      "Cada streamer baixa esse arquivo, então arquivo grande gasta muito tráfego.",
    );
  }
  if (forApp && e == "gif" && mb > 3) {
    throw UploadTooLarge(
      "GIF com ${mb.toStringAsFixed(1)} MB. GIF é um formato muito pesado: envie a mesma animação como vídeo MP4 "
      "(fica até 10x menor) ou use um GIF de até 3 MB.",
    );
  }
  if (!const {"jpg", "jpeg", "png", "webp"}.contains(e)) return (bytes: bytes, ext: e);
  if (bytes.length < 350 * 1024) return (bytes: bytes, ext: e); // ja e leve
  try {
    final decoded = img.decodeImage(bytes);
    // animacao (WebP/PNG animado) sobe intacta: recomprimir viraria imagem parada
    if (decoded == null || decoded.numFrames > 1) return (bytes: bytes, ext: e);
    var image = decoded;
    final side = image.width > image.height ? image.width : image.height;
    if (side > _maxImageSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: _maxImageSide, interpolation: img.Interpolation.average)
          : img.copyResize(image, height: _maxImageSide, interpolation: img.Interpolation.average);
    }
    final keepPng = e == "png" && image.hasAlpha;
    final out = keepPng ? img.encodePng(image, level: 7) : img.encodeJpg(image, quality: 84);
    // so troca se realmente ficou menor
    if (out.length >= bytes.length) return (bytes: bytes, ext: e);
    return (bytes: Uint8List.fromList(out), ext: keepPng ? "png" : "jpg");
  } catch (_) {
    return (bytes: bytes, ext: e);
  }
}

String contentTypeFor(String ext) => switch (ext.toLowerCase()) {
      "png" => "image/png",
      "gif" => "image/gif",
      "webp" => "image/webp",
      "jpg" || "jpeg" => "image/jpeg",
      "mp4" || "m4v" => "video/mp4",
      "mov" => "video/quicktime",
      "webm" => "video/webm",
      "mp3" => "audio/mpeg",
      "m4a" || "aac" => "audio/aac",
      "wav" => "audio/wav",
      "ogg" => "audio/ogg",
      "pdf" => "application/pdf",
      _ => "application/octet-stream",
    };

/// Cache longo: as URLs mudam a cada upload, entao o arquivo nunca muda.
const longCache = "31536000";
