import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../shared/widgets/loading_indicator.dart';
import 'school_config_provider.dart';

class SchoolConfigScreen extends ConsumerStatefulWidget {
  const SchoolConfigScreen({super.key});

  @override
  ConsumerState<SchoolConfigScreen> createState() => _SchoolConfigScreenState();
}

class _SchoolConfigScreenState extends ConsumerState<SchoolConfigScreen> {
  final _nombreCtrl = TextEditingController();
  final _cctCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  String? _turno;
  bool _saving = false;
  bool _loaded = false;

  static const _turnos = ['matutino', 'vespertino', 'nocturno'];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cctCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  void _populate(SchoolConfig config) {
    if (_loaded) return;
    _nombreCtrl.text = config.nombre ?? '';
    _cctCtrl.text = config.cct ?? '';
    _direccionCtrl.text = config.direccion ?? '';
    _turno = config.turno;
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dio = ref.read(apiClientProvider);
      await dio.put('/api/v1/config/', data: {
        'nombre':
            _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
        'cct': _cctCtrl.text.trim().isEmpty ? null : _cctCtrl.text.trim(),
        'turno': _turno,
        'direccion': _direccionCtrl.text.trim().isEmpty
            ? null
            : _direccionCtrl.text.trim(),
      });
      ref.invalidate(schoolConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Información guardada')),
        );
      }
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
    final configAsync = ref.watch(schoolConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Información del plantel')),
      body: configAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('$e')),
        data: (config) {
          _populate(config);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del plantel',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cctCtrl,
                  decoration: const InputDecoration(
                    labelText: 'CCT (Clave de Centro de Trabajo)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _turnos.contains(_turno) ? _turno : null,
                  decoration: const InputDecoration(
                    labelText: 'Turno',
                    border: OutlineInputBorder(),
                  ),
                  items: _turnos
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _turno = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _direccionCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
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
          );
        },
      ),
    );
  }
}
