import "package:flutter/material.dart";
import "package:video_player/video_player.dart";

/// Preview de video do Max: toca automaticamente em loop, mudo (exigencia
/// dos navegadores pra autoplay funcionar sem interacao do usuario antes),
/// com controles basicos pra testar (play/pause, som, progresso).
class MaxVideoPreview extends StatefulWidget {
  final String url;

  const MaxVideoPreview({super.key, required this.url});

  @override
  State<MaxVideoPreview> createState() => _MaxVideoPreviewState();
}

class _MaxVideoPreviewState extends State<MaxVideoPreview> {
  late VideoPlayerController _controller;
  bool _ready = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _controller = _createController();
  }

  @override
  void didUpdateWidget(covariant MaxVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller.dispose();
      _ready = false;
      _muted = true;
      _controller = _createController();
    }
  }

  VideoPlayerController _createController() {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..setVolume(0);
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      controller.play();
    });
    return controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play());
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _controller.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              IconButton(
                icon: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 22),
                onPressed: _togglePlay,
              ),
              IconButton(
                icon: Icon(_muted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 20),
                onPressed: _toggleMute,
              ),
              Expanded(
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  colors: const VideoProgressColors(playedColor: Color(0xFF7A0BD4), bufferedColor: Colors.white24, backgroundColor: Colors.white10),
                ),
              ),
            ]),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(6)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.repeat, color: Colors.white, size: 12),
              SizedBox(width: 4),
              Text("Loop", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ],
    );
  }
}
