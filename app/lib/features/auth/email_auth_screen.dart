import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../data/auth_repository.dart';

/// Acceso con correo: iniciar sesión, crear cuenta o recuperar contraseña.
class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _showPassword = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      _register
          ? await repo.registerWithEmail(_email.text, _password.text)
          : await repo.signInWithEmail(_email.text, _password.text);
      // El router redirige solo cuando cambia la sesión.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final email = _email.text.trim();
    if (_emailError(email) != null) {
      setState(
        () => _error =
            'Escribe tu correo arriba y vuelve a tocar "Olvidé mi contraseña".',
      );
      return;
    }
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        setState(() {
          _info = 'Te enviamos un correo para crear una contraseña nueva.';
          _error = null;
        });
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  static String? _emailError(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Escribe tu correo.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
      return 'Ese correo no es válido.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LevaCourtBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  LevaTopBar(
                    // Sin título: "ENTRA A LEVA" / "CREA TU CUENTA" nombran la pantalla.
                    onBack: () => context.pop(),
                  ),
                  Expanded(
                    child: Form(
                      key: _form,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          LevaSpace.gutter,
                          LevaSpace.s2,
                          LevaSpace.gutter,
                          LevaSpace.s8,
                        ),
                        children: [
                          AnimatedSwitcher(
                            duration: LevaMotion.fast,
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.topLeft,
                              children: [...previous, ?current],
                            ),
                            child: Column(
                              key: ValueKey(_register),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _register ? 'CREA TU' : 'ENTRA A',
                                  style: LevaType.xl,
                                ),
                                GoldText(
                                  _register ? 'CUENTA' : 'LEVA',
                                  style: LevaType.xl,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: LevaSpace.s6),
                          LevaSegmented(
                            options: const ['Iniciar sesión', 'Crear cuenta'],
                            index: _register ? 1 : 0,
                            onChanged: (i) => setState(() {
                              _register = i == 1;
                              _error = null;
                              _info = null;
                            }),
                          ),
                          const SizedBox(height: LevaSpace.s5),
                          LevaField(
                            label: 'Correo',
                            controller: _email,
                            hint: 'tu@correo.com',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: _emailError,
                          ),
                          const SizedBox(height: LevaSpace.s4),
                          LevaField(
                            label: 'Contraseña',
                            controller: _password,
                            obscure: !_showPassword,
                            suffix: IconButton(
                              tooltip: _showPassword
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: LevaColors.tx3,
                                size: 20,
                              ),
                            ),
                            hint: _register ? 'Mínimo 6 caracteres' : null,
                            textInputAction: TextInputAction.done,
                            autofillHints: [
                              _register
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            onSubmitted: (_) => _submit(),
                            validator: (v) {
                              if ((v ?? '').isEmpty) {
                                return 'Escribe tu contraseña.';
                              }
                              if (_register && v!.length < 6) {
                                return 'Usa al menos 6 caracteres.';
                              }
                              return null;
                            },
                          ),
                          if (!_register)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busy ? null : _reset,
                                // Sin padding lateral: alineado al borde del campo.
                                style: TextButton.styleFrom(
                                  foregroundColor: LevaColors.gold200,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 44),
                                ),
                                child: Text(
                                  'Olvidé mi contraseña',
                                  style: LevaType.body(
                                    size: 13,
                                    weight: 600,
                                    color: LevaColors.gold200,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: LevaSpace.s4),
                          if (_error != null) ...[
                            LevaNotice(_error!),
                            const SizedBox(height: LevaSpace.s4),
                          ],
                          if (_info != null) ...[
                            LevaNotice(_info!, kind: LevaNoticeKind.info),
                            const SizedBox(height: LevaSpace.s4),
                          ],
                          LevaButton(
                            label: _register ? 'Crear cuenta' : 'Entrar',
                            loading: _busy,
                            onPressed: _submit,
                          ),
                        ],
                      ),
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
