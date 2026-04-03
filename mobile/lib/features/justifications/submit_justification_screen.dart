import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../shared/models/student.dart';
import '../../shared/widgets/loading_indicator.dart';
import 'justifications_provider.dart';

class SubmitJustificationScreen extends ConsumerStatefulWidget {
  const SubmitJustificationScreen({super.key});

  @override
  ConsumerState<SubmitJustificationScreen> createState() =>
      _SubmitJustificationScreenState();
}

class _SubmitJustificationScreenState
    extends ConsumerState<SubmitJustificationScreen> {
  final _motivoCtrl = TextEditingController();
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  PlatformFile? _pickedFile;
  String? _selectedStudentId;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(myStudentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Subir justificante')),
      body: studentsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (students) {
          // Auto-select if only one student
          if (students.length == 1 && _selectedStudentId == null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => setState(() => _selectedStudentId = students.first.id),
            );
          }
          return _buildForm(context, students);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<Student> students) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (students.length > 1)
          DropdownButtonFormField<String>(
            value: _selectedStudentId,
            decoration: const InputDecoration(
              labelText: 'Alumno',
              border: OutlineInputBorder(),
            ),
            items: students
                .map((s) => DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(
                          '${s.nombre ?? ''} ${s.apellidoPaterno ?? ''}'.trim()),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedStudentId = v),
          )
        else if (students.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Alumno'),
            subtitle: Text(
                '${students.first.nombre ?? ''} ${students.first.apellidoPaterno ?? ''}'
                    .trim()),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(_fechaInicio != null
                    ? _fechaInicio!.toIso8601String().substring(0, 10)
                    : 'Fecha inicio *'),
                onPressed: () => _pickDate(context, isStart: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(_fechaFin != null
                    ? _fechaFin!.toIso8601String().substring(0, 10)
                    : 'Fecha fin'),
                onPressed: () => _pickDate(context, isStart: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _motivoCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.attach_file),
          label: Text(_pickedFile != null
              ? _pickedFile!.name
              : 'Adjuntar archivo (opcional)'),
          onPressed: _pickFile,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enviar justificante'),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null) setState(() => _pickedFile = result.files.first);
  }

  Future<void> _pickDate(BuildContext context, {required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _fechaInicio = picked;
        } else {
          _fechaFin = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedStudentId == null) {
      setState(() => _error = 'Selecciona un alumno');
      return;
    }
    if (_fechaInicio == null) {
      setState(() => _error = 'Selecciona la fecha de inicio');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final formData = FormData.fromMap({
        'student_id': _selectedStudentId,
        'fecha_inicio': _fechaInicio!.toIso8601String().substring(0, 10),
        if (_fechaFin != null)
          'fecha_fin': _fechaFin!.toIso8601String().substring(0, 10),
        if (_motivoCtrl.text.isNotEmpty) 'motivo': _motivoCtrl.text.trim(),
        if (_pickedFile != null && _pickedFile!.path != null)
          'file': await MultipartFile.fromFile(
            _pickedFile!.path!,
            filename: _pickedFile!.name,
          ),
      });
      await ref.read(apiClientProvider).post(
            '/api/v1/justifications/',
            data: formData,
            options: Options(contentType: 'multipart/form-data'),
          );
      ref.invalidate(justificationsProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Error al enviar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
