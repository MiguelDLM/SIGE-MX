import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/event.dart';
import 'events_provider.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  final Event? existing;
  const EventFormScreen({super.key, this.existing});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  late final TextEditingController _tituloCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _inicioCtrl;
  late final TextEditingController _finCtrl;
  String? _tipo;
  bool _saving = false;

  static const _tipos = ['academico', 'cultural', 'deportivo', 'administrativo'];

  @override
  void initState() {
    super.initState();
    _tituloCtrl = TextEditingController(text: widget.existing?.titulo ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.descripcion ?? '');
    _inicioCtrl = TextEditingController(
      text: widget.existing?.fechaInicio?.substring(0, 16) ?? '',
    );
    _finCtrl = TextEditingController(
      text: widget.existing?.fechaFin?.substring(0, 16) ?? '',
    );
    _tipo = widget.existing?.tipo;
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _inicioCtrl.dispose();
    _finCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_tituloCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es requerido')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(apiClientProvider);
      final body = {
        'titulo': _tituloCtrl.text.trim(),
        'descripcion':
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'tipo': _tipo,
        'fecha_inicio':
            _inicioCtrl.text.trim().isEmpty ? null : _inicioCtrl.text.trim(),
        'fecha_fin':
            _finCtrl.text.trim().isEmpty ? null : _finCtrl.text.trim(),
      };
      if (widget.existing == null) {
        await dio.post('/api/v1/events/', data: body);
      } else {
        await dio.patch('/api/v1/events/${widget.existing!.id}', data: body);
      }
      ref.invalidate(eventsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Nuevo evento' : 'Editar evento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tituloCtrl,
              decoration: const InputDecoration(
                labelText: 'Título *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _tipos.contains(_tipo) ? _tipo : null,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: _tipos
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _tipo = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inicioCtrl,
              decoration: const InputDecoration(
                labelText: 'Fecha inicio (YYYY-MM-DDTHH:MM)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _finCtrl,
              decoration: const InputDecoration(
                labelText: 'Fecha fin (YYYY-MM-DDTHH:MM)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
