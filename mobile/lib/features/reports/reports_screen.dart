import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_notifier.dart';
import '../../core/auth/auth_state.dart';
import '../../shared/models/student.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../justifications/justifications_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);
    return authAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (auth) {
        if (auth is! AuthAuthenticated) return const SizedBox.shrink();
        final isPadreOrAlumno =
            auth.primaryRole == 'padre' || auth.primaryRole == 'alumno';
        return Scaffold(
          appBar: AppBar(title: const Text('Reportes')),
          body: isPadreOrAlumno
              ? const _PdfReportsBody()
              : const Center(
                  child: Text('Reportes — próximamente para directivos')),
        );
      },
    );
  }
}

class _PdfReportsBody extends ConsumerWidget {
  const _PdfReportsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(myStudentsProvider);
    return studentsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (students) {
        if (students.isEmpty) {
          return const Center(
              child: Text('No hay alumnos vinculados a tu cuenta'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (_, i) => _StudentReportCard(student: students[i]),
        );
      },
    );
  }
}

class _StudentReportCard extends StatelessWidget {
  final Student student;
  const _StudentReportCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final name =
        '${student.nombre ?? ''} ${student.apellidoPaterno ?? ''}'.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isNotEmpty ? name : student.matricula,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(student.matricula,
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DownloadButton(
                    key: Key('boleta_${student.id}'),
                    label: 'Boleta',
                    icon: Icons.grade_outlined,
                    studentId: student.id,
                    type: 'boleta',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DownloadButton(
                    key: Key('constancia_${student.id}'),
                    label: 'Constancia',
                    icon: Icons.description_outlined,
                    studentId: student.id,
                    type: 'constancia',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadButton extends ConsumerStatefulWidget {
  final String label;
  final IconData icon;
  final String studentId;
  final String type;

  const _DownloadButton({
    super.key,
    required this.label,
    required this.icon,
    required this.studentId,
    required this.type,
  });

  @override
  ConsumerState<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends ConsumerState<_DownloadButton> {
  bool _loading = false;

  Future<void> _download() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(apiClientProvider);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${widget.type}_${widget.studentId}.pdf';

      await dio.download(
        '/api/v1/reports/students/${widget.studentId}/${widget.type}',
        path,
        options: Options(responseType: ResponseType.bytes),
      );

      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(widget.icon),
      label: Text(widget.label),
      onPressed: _loading ? null : _download,
    );
  }
}
