import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/academic_cycle.dart';
import '../../shared/widgets/loading_indicator.dart';
import 'cycles_provider.dart';

class CyclesScreen extends ConsumerWidget {
  const CyclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cyclesAsync = ref.watch(cyclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ciclos escolares')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCycleDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: cyclesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('$e')),
        data: (cycles) {
          if (cycles.isEmpty) {
            return const Center(child: Text('Sin ciclos registrados'));
          }
          return ListView.builder(
            itemCount: cycles.length,
            itemBuilder: (_, i) => _CycleTile(
              cycle: cycles[i],
              onTap: () => _showCycleDialog(context, ref, cycles[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCycleDialog(
    BuildContext context,
    WidgetRef ref,
    AcademicCycle? existing,
  ) async {
    await showDialog(
      context: context,
      builder: (_) => _CycleDialog(existing: existing, widgetRef: ref),
    );
  }
}

class _CycleTile extends StatelessWidget {
  final AcademicCycle cycle;
  final VoidCallback onTap;
  const _CycleTile({required this.cycle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.calendar_month,
        color: cycle.activo ? Theme.of(context).colorScheme.primary : Colors.grey,
      ),
      title: Text(cycle.nombre ?? 'Sin nombre'),
      subtitle: Text('${cycle.fechaInicio ?? '?'} — ${cycle.fechaFin ?? '?'}'),
      trailing: cycle.activo
          ? Chip(
              label: const Text('Activo'),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _CycleDialog extends ConsumerStatefulWidget {
  final AcademicCycle? existing;
  final WidgetRef widgetRef;
  const _CycleDialog({this.existing, required this.widgetRef});

  @override
  ConsumerState<_CycleDialog> createState() => _CycleDialogState();
}

class _CycleDialogState extends ConsumerState<_CycleDialog> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _inicioCtrl;
  late final TextEditingController _finCtrl;
  late bool _activo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.existing?.nombre ?? '');
    _inicioCtrl = TextEditingController(text: widget.existing?.fechaInicio ?? '');
    _finCtrl = TextEditingController(text: widget.existing?.fechaFin ?? '');
    _activo = widget.existing?.activo ?? false;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _inicioCtrl.dispose();
    _finCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dio = ref.read(apiClientProvider);
      final body = {
        'nombre': _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
        'fecha_inicio': _inicioCtrl.text.trim().isEmpty ? null : _inicioCtrl.text.trim(),
        'fecha_fin': _finCtrl.text.trim().isEmpty ? null : _finCtrl.text.trim(),
        'activo': _activo,
      };
      if (widget.existing == null) {
        await dio.post('/api/v1/academic-cycles/', data: body);
      } else {
        await dio.patch('/api/v1/academic-cycles/${widget.existing!.id}', data: body);
      }
      ref.invalidate(cyclesProvider);
      if (mounted) Navigator.of(context).pop();
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
    return AlertDialog(
      title: Text(widget.existing == null ? 'Nuevo ciclo' : 'Editar ciclo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre (ej. 2024-2025)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inicioCtrl,
              decoration: const InputDecoration(
                labelText: 'Fecha inicio (YYYY-MM-DD)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _finCtrl,
              decoration: const InputDecoration(
                labelText: 'Fecha fin (YYYY-MM-DD)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Activo'),
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
