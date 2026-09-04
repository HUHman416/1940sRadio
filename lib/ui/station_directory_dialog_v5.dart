import 'package:flutter/material.dart';

import '../stations/radio_station.dart';
import '../stations/station_store.dart';

class StationDirectoryDialogV5 extends StatefulWidget {
  const StationDirectoryDialogV5({
    super.key,
    required this.store,
    required this.onTune,
    required this.testStream,
  });

  final StationStore store;
  final Future<void> Function(RadioStation station) onTune;
  final Future<bool> Function(String url) testStream;

  @override
  State<StationDirectoryDialogV5> createState() => _StationDirectoryDialogV5State();
}

class _StationDirectoryDialogV5State extends State<StationDirectoryDialogV5> {
  Future<void> _openEditor([RadioStation? station]) async {
    final draft = await showDialog<_StationDraft>(
      context: context,
      builder: (context) => _StationEditorDialog(
        station: station,
        testStream: widget.testStream,
      ),
    );
    if (draft == null) return;

    if (station == null) {
      final added = await widget.store.addStation(
        name: draft.name,
        url: draft.url,
        subtitle: draft.subtitle,
      );
      await widget.onTune(added);
    } else {
      await widget.store.updateStation(
        station,
        name: draft.name,
        url: draft.url,
        subtitle: draft.subtitle,
      );
      final updated = widget.store.stationById(station.id);
      if (updated != null && widget.store.selectedStationId == station.id) {
        await widget.onTune(updated);
      }
    }
  }

  Future<void> _remove(RadioStation station) async {
    final remove = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('REMOVE STATION?'),
            content: Text('Remove ${station.name} from this receiver?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('KEEP')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('REMOVE')),
            ],
          ),
        ) ??
        false;
    if (!remove) return;
    await widget.store.removeStation(station);
    await widget.onTune(widget.store.selectedStation);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: [Color(0xff704026), Color(0xff351b12)]),
          border: Border.all(color: const Color(0xff160b07), width: 4),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'STATION DIRECTORY',
                    style: TextStyle(color: Color(0xffffd894), fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2.2),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('ADD SIGNAL'),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const Divider(color: Color(0xff9b7045)),
            Expanded(
              child: AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) => ListView.separated(
                  itemCount: widget.store.stations.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0x447f5a3c)),
                  itemBuilder: (context, index) {
                    final station = widget.store.stations[index];
                    final selected = station.id == widget.store.selectedStationId;
                    final favorite = widget.store.isFavorite(station.id);
                    return ListTile(
                      leading: IconButton(
                        tooltip: favorite ? 'Remove favorite' : 'Add favorite',
                        onPressed: () => widget.store.toggleFavorite(station),
                        icon: Icon(favorite ? Icons.star : Icons.star_border),
                        color: const Color(0xffffd894),
                      ),
                      title: Text(
                        station.name,
                        style: TextStyle(
                          color: selected ? const Color(0xffffd894) : Colors.white,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        station.subtitle.isEmpty ? station.url : station.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => widget.onTune(station),
                      trailing: station.builtIn
                          ? const Chip(label: Text('FEATURED'))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(onPressed: () => _openEditor(station), icon: const Icon(Icons.edit_outlined)),
                                IconButton(onPressed: () => _remove(station), icon: const Icon(Icons.delete_outline)),
                              ],
                            ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationDraft {
  const _StationDraft({required this.name, required this.url, required this.subtitle});
  final String name;
  final String url;
  final String subtitle;
}

class _StationEditorDialog extends StatefulWidget {
  const _StationEditorDialog({required this.testStream, this.station});
  final RadioStation? station;
  final Future<bool> Function(String url) testStream;

  @override
  State<_StationEditorDialog> createState() => _StationEditorDialogState();
}

class _StationEditorDialogState extends State<_StationEditorDialog> {
  late final TextEditingController nameController;
  late final TextEditingController urlController;
  late final TextEditingController subtitleController;
  String? status;
  bool testing = false;
  bool testedOkay = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.station?.name ?? '');
    urlController = TextEditingController(text: widget.station?.url ?? '');
    subtitleController = TextEditingController(text: widget.station?.subtitle ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    urlController.dispose();
    subtitleController.dispose();
    super.dispose();
  }

  bool _validUrl() {
    final uri = Uri.tryParse(urlController.text.trim());
    return uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> _test() async {
    if (!_validUrl()) {
      setState(() => status = 'Enter a complete http:// or https:// direct stream URL first.');
      return;
    }
    setState(() {
      testing = true;
      status = 'TESTING SIGNAL…';
      testedOkay = false;
    });
    final okay = await widget.testStream(urlController.text.trim());
    if (!mounted) return;
    setState(() {
      testing = false;
      testedOkay = okay;
      status = okay ? 'SIGNAL ACQUIRED — stream opened successfully.' : 'NO CARRIER — stream could not be opened.';
    });
  }

  void _save() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() => status = 'Give the station a name.');
      return;
    }
    if (!_validUrl()) {
      setState(() => status = 'Enter a complete http:// or https:// direct stream URL.');
      return;
    }
    Navigator.pop(
      context,
      _StationDraft(name: name, url: urlController.text.trim(), subtitle: subtitleController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xff3b2115),
      title: Text(widget.station == null ? 'ADD STATION' : 'EDIT STATION'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Station name')),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'Direct stream URL', hintText: 'https://example.com/listen'),
              onChanged: (_) => setState(() => testedOkay = false),
            ),
            const SizedBox(height: 10),
            TextField(controller: subtitleController, decoration: const InputDecoration(labelText: 'Dial subtitle (optional)')),
            if (status != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  status!,
                  style: TextStyle(color: testedOkay ? const Color(0xffb8efb5) : const Color(0xffffd894)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        TextButton(onPressed: testing ? null : _test, child: Text(testing ? 'TESTING…' : 'TEST SIGNAL')),
        FilledButton(onPressed: _save, child: const Text('SAVE STATION')),
      ],
    );
  }
}
