import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/server_config.dart';

class ServerSetupScreen extends ConsumerStatefulWidget {
  const ServerSetupScreen({super.key});

  @override
  ConsumerState<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends ConsumerState<ServerSetupScreen> {
  final _controller = TextEditingController(text: 'http://');
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final raw = _controller.text.trim();
    final url = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;

    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));
      await dio.get('$url/health');
      await ref.read(serverUrlProvider.notifier).setUrl(url);
      if (mounted) context.go('/login');
    } on DioException catch (e) {
      setState(() {
        _error = (e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout)
            ? 'No se pudo conectar. Verifica la URL y que el servidor esté activo.'
            : 'Error al conectar: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _error = 'Error inesperado: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school, size: 72, color: Color(0xFF1976D2)),
                  const SizedBox(height: 16),
                  const Text(
                    'SIGE-MX',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configura el servidor',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _controller,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'URL del servidor',
                      hintText: 'http://192.168.1.x:8000',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Ingresa la URL del servidor';
                      }
                      if (!v.startsWith('http://') &&
                          !v.startsWith('https://')) {
                        return 'Debe comenzar con http:// o https://';
                      }
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _connect,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.wifi_tethering),
                      label: Text(_loading ? 'Conectando…' : 'Conectar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
