import "package:flutter/material.dart";
import "../calendar_colors.dart";
import "../models/event_category.dart";
import "../services/calendar_service.dart";

class FiltersPanel extends StatefulWidget {
  final List<EventCategory> categories;
  final String searchText;
  final ValueChanged<String> onSearchChanged;
  final String? scope;
  final ValueChanged<String?> onScopeChanged;
  final Set<String> selectedManagerIds;
  final ValueChanged<String> onManagerToggle;
  final Set<String> selectedCategoryIds;
  final ValueChanged<String> onCategoryToggle;
  final bool showManagerFilter;
  final VoidCallback onManageCategories;

  const FiltersPanel({
    super.key,
    required this.categories,
    required this.searchText,
    required this.onSearchChanged,
    required this.scope,
    required this.onScopeChanged,
    required this.selectedManagerIds,
    required this.onManagerToggle,
    required this.selectedCategoryIds,
    required this.onCategoryToggle,
    required this.onManageCategories,
    this.showManagerFilter = true,
  });

  @override
  State<FiltersPanel> createState() => _FiltersPanelState();
}

class _FiltersPanelState extends State<FiltersPanel> {
  final _service = CalendarService();
  List<Map<String, dynamic>> _managers = [];

  @override
  void initState() {
    super.initState();
    if (widget.showManagerFilter) _loadManagers();
  }

  Future<void> _loadManagers() async {
    final rows = await _service.fetchManagerOptions();
    if (mounted) setState(() => _managers = rows);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, color: Colors.white54, size: 18),
              hintText: "Pesquisar evento",
              hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
              isDense: true,
            ),
            onChanged: widget.onSearchChanged,
            controller: TextEditingController(text: widget.searchText)..selection = TextSelection.collapsed(offset: widget.searchText.length),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String?>(
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: null, label: Text("Todos", style: TextStyle(fontSize: 11))),
              ButtonSegment(value: "agencia", label: Text("Agência", style: TextStyle(fontSize: 11))),
              ButtonSegment(value: "streamer", label: Text("Streamers", style: TextStyle(fontSize: 11))),
            ],
            selected: {widget.scope},
            onSelectionChanged: (s) => widget.onScopeChanged(s.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text("Categorias", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
              IconButton(
                onPressed: widget.onManageCategories,
                icon: const Icon(Icons.settings, color: Colors.white38, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 14,
                tooltip: "Gerenciar categorias",
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...widget.categories.where((c) => c.matchesScope(widget.scope)).map((c) {
            final checked = widget.selectedCategoryIds.contains(c.id);
            return InkWell(
              onTap: () => widget.onCategoryToggle(c.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Checkbox(value: checked, onChanged: (_) => widget.onCategoryToggle(c.id), visualDensity: VisualDensity.compact, activeColor: hexToColor(c.color)),
                    CircleAvatar(radius: 5, backgroundColor: hexToColor(c.color)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(c.name, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            );
          }),
          if (widget.showManagerFilter) ...[
            const SizedBox(height: 16),
            const Text("Colaboradores", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(
                  children: _managers.map((m) {
                    final id = m["id"] as String;
                    final checked = widget.selectedManagerIds.contains(id);
                    return InkWell(
                      onTap: () => widget.onManagerToggle(id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Checkbox(value: checked, onChanged: (_) => widget.onManagerToggle(id), visualDensity: VisualDensity.compact),
                            CircleAvatar(
                              radius: 9,
                              backgroundColor: Colors.white24,
                              backgroundImage: m["photo_url"] != null ? NetworkImage(m["photo_url"] as String) : null,
                              child: m["photo_url"] == null ? const Icon(Icons.person, size: 10, color: Colors.white70) : null,
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(managerDisplayName(m), style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
