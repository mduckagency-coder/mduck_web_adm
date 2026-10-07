import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "../inventario_service.dart";
import "../models/inventory_entry.dart";

const _purple = Color(0xFF7A0BD4);

/// Cadastro/edicao de um registro do inventario, em fluxo simples:
/// tipo -> titulo e data -> detalhes -> valor/imagem (opcionais) ->
/// visibilidade -> salvar. Devolve o registro salvo.
class InventoryEntryFormDialog extends StatefulWidget {
  final String streamerId;
  final String streamerName;
  final InventoryEntry? existing;

  const InventoryEntryFormDialog({super.key, required this.streamerId, required this.streamerName, this.existing});

  @override
  State<InventoryEntryFormDialog> createState() => _InventoryEntryFormDialogState();
}

class _InventoryEntryFormDialogState extends State<InventoryEntryFormDialog> {
  final _service = InventarioService();
  late final _title = TextEditingController(text: widget.existing?.title ?? "");
  late final _description = TextEditingController(text: widget.existing?.description ?? "");
  late final _amount = TextEditingController(
    text: widget.existing?.amount == null ? "" : widget.existing!.amount!.toStringAsFixed(2).replaceAll(".", ","),
  );
  late final _note = TextEditingController(text: widget.existing?.internalNote ?? "");

  late String? _type = widget.existing?.category;
  late DateTime _date = widget.existing?.occurredAt ?? DateTime.now();
  late String? _imageUrl = widget.existing?.imageUrl;
  late bool _visible = widget.existing?.visibleToStreamer ?? true;
  late bool _showAmount = widget.existing?.showAmount ?? true;
  late String _status = widget.existing?.status ?? "concluido";
  late bool _withAmount = widget.existing?.amount != null;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _pickType(InventoryType t) {
    setState(() {
      _type = t.key;
      if (widget.existing == null) _withAmount = t.usuallyHasAmount;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    if (result.files.single.size > 5 * 1024 * 1024) {
      setState(() => _error = "Imagem acima de 5MB.");
      return;
    }
    setState(() => _uploading = true);
    try {
      final url = await _service.uploadImage(result.files.single);
      setState(() => _imageUrl = url);
    } catch (e) {
      setState(() => _error = "Erro ao enviar a imagem: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  double? _parseAmount() {
    final raw = _amount.text.trim().replaceAll("R\$", "").replaceAll(" ", "");
    if (raw.isEmpty) return null;
    // "1.234,56" -> 1234.56 ; "500" -> 500
    final normalized = raw.contains(",") ? raw.replaceAll(".", "").replaceAll(",", ".") : raw;
    return double.tryParse(normalized);
  }

  Future<void> _save() async {
    if (_type == null) return setState(() => _error = "Escolha o tipo do registro.");
    if (_title.text.trim().isEmpty) return setState(() => _error = "Dê um título ao registro.");
    final amount = _withAmount ? _parseAmount() : null;
    if (_withAmount && _amount.text.trim().isNotEmpty && amount == null) {
      return setState(() => _error = "Valor inválido. Use por exemplo 500 ou 1.234,56.");
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _service.save(
        id: widget.existing?.id,
        streamerId: widget.streamerId,
        category: _type!,
        title: _title.text,
        description: _description.text,
        occurredAt: _date,
        amount: amount,
        showAmount: _showAmount,
        imageUrl: _imageUrl,
        internalNote: _note.text,
        status: _status,
        visibleToStreamer: _visible,
      );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) setState(() => _error = "Erro ao salvar: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _step(int n, String title, {String? help}) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: _purple, shape: BoxShape.circle),
            child: Text("$n", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          if (help != null) ...[
            const SizedBox(width: 8),
            Flexible(child: Text(help, style: const TextStyle(color: Colors.white38, fontSize: 11))),
          ],
        ]),
      );

  InputDecoration _input(String hint, {String? prefix}) => InputDecoration(
        border: const OutlineInputBorder(),
        isDense: true,
        hintText: hint,
        prefixText: prefix,
        hintStyle: const TextStyle(color: Colors.white38),
        counterStyle: const TextStyle(color: Colors.white38),
      );

  @override
  Widget build(BuildContext context) {
    final type = _type == null ? null : inventoryTypeOf(_type!);
    return Dialog(
      backgroundColor: const Color(0xFF17131F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 880),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(type?.emoji ?? "🎒", style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.existing == null ? "Registrar no inventário" : "Editar registro",
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("@${widget.streamerName}", style: const TextStyle(color: Color(0xFFB98CFF), fontSize: 13)),
                ]),
              ),
            ]),

            _step(1, "Tipo"),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in inventoryTypes.where((t) => !t.legacy || t.key == widget.existing?.category))
                InkWell(
                  onTap: () => _pickType(t),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 104,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _type == t.key ? t.color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _type == t.key ? t.color : Colors.white12, width: _type == t.key ? 2 : 1),
                    ),
                    child: Column(children: [
                      Text(t.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(t.label,
                          style: TextStyle(color: _type == t.key ? Colors.white : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ]),

            _step(2, "Título e data"),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextField(
                  controller: _title,
                  maxLength: 90,
                  style: const TextStyle(color: Colors.white),
                  decoration: _input("Ex: Presente do campeonato de setembro"),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event, size: 16, color: Colors.white70),
                label: Text(
                  "${_date.day.toString().padLeft(2, "0")}/${_date.month.toString().padLeft(2, "0")}/${_date.year}",
                  style: const TextStyle(color: Colors.white70),
                ),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16)),
              ),
            ]),

            _step(3, "Detalhes", help: "o que aconteceu"),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              maxLength: 600,
              style: const TextStyle(color: Colors.white),
              decoration: _input("Ex: Presente entregue pela participação no campeonato."),
            ),

            _step(4, "Valor e imagem", help: "opcionais"),
            CheckboxListTile(
              value: _withAmount,
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: _purple,
              title: const Text("Tem valor (Pix, premiação, bônus...)", style: TextStyle(color: Colors.white70, fontSize: 13)),
              onChanged: (v) => setState(() => _withAmount = v ?? false),
            ),
            if (_withAmount)
              Row(children: [
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: _input("500,00", prefix: "R\$ "),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile(
                    value: _showAmount,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: _purple,
                    title: const Text("Mostrar o valor no app", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    onChanged: (v) => setState(() => _showAmount = v),
                  ),
                ),
              ]),
            const SizedBox(height: 6),
            Row(children: [
              if (_imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(_imageUrl!, width: 64, height: 64, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
              ],
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickImage,
                icon: const Icon(Icons.image_outlined, size: 16, color: Colors.white70),
                label: Text(_uploading ? "Enviando..." : (_imageUrl == null ? "Adicionar imagem" : "Trocar imagem"),
                    style: const TextStyle(color: Colors.white70)),
              ),
              if (_imageUrl != null)
                TextButton(onPressed: () => setState(() => _imageUrl = null), child: const Text("Remover", style: TextStyle(color: Colors.redAccent))),
            ]),

            _step(5, "Visibilidade e status"),
            Container(
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                SwitchListTile(
                  value: _visible,
                  activeThumbColor: Colors.greenAccent,
                  title: Text(_visible ? "👁 Visível para o streamer" : "🔒 Registro interno",
                      style: TextStyle(color: _visible ? Colors.greenAccent : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                    _visible
                        ? "Aparece no Inventário do app e na linha do tempo do CRM."
                        : "Fica só no painel e no CRM (ex: ligação de suporte). Não aparece no app.",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onChanged: (v) => setState(() => _visible = v),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(children: [
                    const Text("Status:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(width: 10),
                    for (final s in inventoryStatuses.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(s.value),
                          selected: _status == s.key,
                          selectedColor: _purple,
                          backgroundColor: Colors.white10,
                          labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                          onSelected: (_) => setState(() => _status = s.key),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: _input("Observação interna (opcional, nunca aparece no app)"),
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _saving || _uploading ? null : _save,
                icon: const Icon(Icons.check, size: 18),
                label: Text(_saving ? "Salvando..." : "Salvar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
