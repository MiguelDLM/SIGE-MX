import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_notifier.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ref.read(apiClientProvider);
      await dio.post('/api/v1/auth/change-password', data: {
        'new_password': _passCtrl.text,
      });
      // Refresh auth state to update must_change_password flag
      ref.invalidate(authNotifierProvider);
    } catch (e) {
      setState(() => _error = 'Error al cambiar contraseña: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Actualizar Contraseña'), automaticallyImplyLeading: false),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_reset, size: 64, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'Por seguridad, debes cambiar tu contraseña temporal antes de continuar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nueva Contraseña', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar Contraseña', border: OutlineInputBorder()),
                  validator: (v) => v != _passCtrl.text ? 'Las contraseñas no coinciden' : null,
                ),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Actualizar y Entrar'),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                  child: const Text('Cerrar Sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
