import 'package:flutter/material.dart';

import '../stations/radio_station.dart';
import '../stations/station_store.dart';
import 'vintage_button.dart';

class StationDirectoryDialog extends StatelessWidget {
  const StationDirectoryDialog({
    super.key,
    required this.store,
    required this.onTune,
  });

  final StationStore store;
  final Future<void> Function(RadioStation station) onTune;

  Future<void> _openEditor(BuildContext context, [RadioStation? station]) async {
    final draft = await showDialog<StationDraft>(
      context: context,
      builder: (context) => StationEditorDialog(station: station),
    );
    if (draft == null) return;

    if (station == null) {
      final added = await store.addStation(
        name: draft.name,
        url: draft.url,
        subtitle: draft.subtitle,
      );
      await onTune(added);
      return;
    }

    await store.updateStation(
      station,
      name: draft.name,
      url: draft.url,
      subtitle: draft.subtitle,
    );
    final updated = store.stationById(station.id);
    if (updated != null && store.selectedStationId == station.id) {
      await onTune(updated);
    }
  }

  Future<void> _remove(BuildContext context, RadioStation station) async {
    final shouldRemove = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xff3b2115),
            title: const Text('Remove station?'),
            content: Text('Remove ${station.name} from the directory?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('KEEP'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('REMOVE'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldRemove) return;
    await store.removeStation(station);
    await onTune(store.selectedStation);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 620),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xff704026), Color(0xff351b12)],
          ),
          border: Border.all(color: const Color(0xff160b07), width: 4),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'STATION DIRECTORY',
                    style: TextStyle(
                      color: Color(0xffffd894),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.3,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close directory',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(color: Color(0xff9b7045)),
            Flexible(
              child: AnimatedBuilder(
                animation: store,
                builder: (context, _) => ListView.separated(
                  shrinkWrap: true,
                  itemCount: store.stations.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Color(0x447f5a3c)),
                  itemBuilder: (context, index) {
                    final station = store.stations[index];
                    final selected = station.id == store.selectedStationId;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      leading: Icon(
                        station.builtIn ? Icons.star : Icons.radio,
                        color: selected
                            ? const Color(0xffffd894)
                            : const Color(0xffc49a68),
                      ),
                      title: Text(
                        station.name,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xffffd894)
                              : Colors.white,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        station.subtitle.isEmpty ? station.url : station.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onTune(station),
                      trailing: station.builtIn
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit station',
                                  onPressed: () => _openEditor(context, station),
                                  icon: const Icon(Icons.edit_outlined, size: 19),
                                ),
                                IconButton(
                                  tooltip: 'Remove station',
                                  onPressed: () => _remove(context, station),
                                  icon: const Icon(Icons.delete_outline, size: 19),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: VintageButton(
                label: 'ADD STATION',
                icon: Icons.add,
                onPressed: () => _openEditor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StationDraft {
  const StationDraft({
    required this.name,
    required this.url,
    required this.subtitle,
  });

  final String name;
  final String url;
  final String subtitle;
}

class StationEditorDialog extends StatefulWidget {
  const StationEditorDialog({super.key, this.station});

  final RadioStation? station;

  @override
  State<StationEditorDialog> createState() => _StationEditorDialogState();
}

class _StationEditorDialogState extends State<StationEditorDialog> {
  late final TextEditingController nameController;
  late final TextEditingController urlController;
  late final TextEditingController subtitleController;
  String? error;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.station?.name ?? '');
    urlController = TextEditingController(text: widget.station?.url ?? '');
    subtitleController =
        TextEditingController(text: widget.station?.subtitle ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    urlController.dispose();
    subtitleController.dispose();
    super.dispose();
  }

  void _save() {
    final name = nameController.text.trim();
    final url = urlController.text.trim();
    final uri = Uri.tryParse(url);

    if (name.isEmpty) {
      setState(() => error = 'Give the station a name.');
      return;
    }
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(
        () => error = 'Enter a complete http:// or https:// stream URL.',
      );
      return;
    }

    Navigator.pop(
      context,
      StationDraft(
        name: name,
        url: url,
        subtitle: subtitleController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xff3b2115),
      title: Text(widget.station == null ? 'ADD STATION' : 'EDIT STATION'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Station name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Direct stream URL',
                hintText: 'https://example.com/radio.mp3',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: subtitleController,
              decoration: const InputDecoration(
                labelText: 'Dial subtitle (optional)',
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  error!,
                  style: const TextStyle(color: Color(0xffffb4a9)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        TextButton(onPressed: _save, child: const Text('SAVE')),
      ],
    );
  }
}
